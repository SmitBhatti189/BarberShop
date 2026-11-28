import type { Db } from '../../db/database.js';
import { withTransaction, type Executor } from '../../db/transaction.js';
import { BusinessRuleError, ConflictError, NotFoundError } from '../../shared/errors.js';
import { fromPaise, percentOf, rateToBasisPoints, toPaise } from '../../shared/money.js';
import { decodeCursor, encodeCursor, type CursorPageMeta } from '../../shared/pagination.js';
import type { Principal } from '../auth/principal.repository.js';
import * as repo from './inventory.repository.js';
import type {
  AdjustmentInput,
  CreateProductInput,
  ListProductsQuery,
  MovementDto,
  ProductDto,
  PurchaseInput,
  UpdateProductInput,
} from './inventory.schemas.js';

/**
 * Selling price = MRP less the product's default discount, rounded to the
 * paisa (owner rule, 2026-11-24). E.g. MRP 2000.00, 10 % → 1800.00.
 * The single place this is computed; billing will use it too.
 */
export function sellingPrice(mrp: string, discountPct: string): string {
  const mrpPaise = toPaise(mrp);
  return fromPaise(mrpPaise - percentOf(mrpPaise, rateToBasisPoints(discountPct)));
}

function toDto(row: repo.ProductRow): ProductDto {
  return {
    ...row,
    sellingPrice: sellingPrice(row.mrp, row.defaultDiscountPct),
    isLowStock: row.stockQuantity <= row.lowStockThreshold,
  };
}

function movementDto(row: repo.MovementRow): MovementDto {
  return { ...row, createdAt: row.createdAt.toISOString() };
}

/**
 * Products and stock. Every stock change locks that product's stock row,
 * checks the result against the negative-stock setting, updates the balance
 * and writes the ledger entry — all in one transaction, so concurrent
 * deliveries, adjustments (and later sales) can never lose or invent units.
 */
export class InventoryService {
  constructor(private readonly db: Db) {}

  async list(branchId: number, query: ListProductsQuery) {
    const { rows, total } = await repo.listProducts(this.db, branchId, query);
    return { rows: rows.map(toDto), total };
  }

  async get(branchId: number, id: number): Promise<ProductDto> {
    const row = await repo.findProduct(this.db, branchId, id);
    if (!row) throw new NotFoundError('Product');
    return toDto(row);
  }

  suggestions() {
    return repo.suggestions(this.db);
  }

  async create(actor: Principal, input: CreateProductInput): Promise<ProductDto> {
    const id = await withDuplicateName(() =>
      withTransaction(this.db, async (trx) => {
        const productId = await repo.insertProduct(trx, {
          name: input.name,
          brand: input.brand ?? null,
          category: input.category ?? null,
          mrp: input.mrp,
          defaultDiscountPct: input.defaultDiscountPct,
        });
        await repo.ensureStockRow(trx, actor.branchId, productId);
        await repo.setLowStockThreshold(trx, actor.branchId, productId, input.lowStockThreshold);
        if (input.openingStock) {
          await this.purchaseIn(trx, actor, productId, { ...input.openingStock, note: input.openingStock.note ?? 'Opening stock' });
        }
        return productId;
      }),
    );
    return this.get(actor.branchId, id);
  }

  async update(actor: Principal, id: number, input: UpdateProductInput): Promise<ProductDto> {
    await withDuplicateName(() =>
      withTransaction(this.db, async (trx) => {
        const saved = await repo.updateProductIfVersion(trx, id, input.version, {
          ...(input.name !== undefined && { name: input.name }),
          ...(input.brand !== undefined && { brand: input.brand }),
          ...(input.category !== undefined && { category: input.category }),
          ...(input.mrp !== undefined && { mrp: input.mrp }),
          ...(input.defaultDiscountPct !== undefined && { default_discount_pct: input.defaultDiscountPct }),
        });
        if (!saved) {
          if (!(await repo.productExists(trx, id))) throw new NotFoundError('Product');
          throw new ConflictError('STALE', 'Someone else changed this product. Reload and try again.');
        }
        if (input.lowStockThreshold !== undefined) {
          await repo.ensureStockRow(trx, actor.branchId, id);
          await repo.setLowStockThreshold(trx, actor.branchId, id, input.lowStockThreshold);
        }
      }),
    );
    return this.get(actor.branchId, id);
  }

  async setActive(actor: Principal, id: number, active: boolean): Promise<ProductDto> {
    await this.get(actor.branchId, id);
    await withDuplicateName(() => repo.setProductActive(this.db, id, active));
    return this.get(actor.branchId, id);
  }

  /** A delivery: adds stock and records this lot's buying price. */
  async receive(actor: Principal, id: number, input: PurchaseInput) {
    const movementId = await withTransaction(this.db, async (trx) => {
      await this.mustBeActive(trx, actor.branchId, id);
      return this.purchaseIn(trx, actor, id, input);
    });
    return this.changeResult(actor.branchId, id, movementId);
  }

  /** Manual correction in or out, always with a reason. */
  async adjust(actor: Principal, id: number, input: AdjustmentInput) {
    const delta = input.direction === 'IN' ? input.quantity : -input.quantity;
    const movementId = await withTransaction(this.db, async (trx) => {
      await this.mustBeActive(trx, actor.branchId, id);
      return this.applyMovement(trx, actor, id, delta, {
        type: 'ADJUSTMENT',
        unitCost: null,
        supplierName: null,
        invoiceNo: null,
        reason: input.reason,
        note: input.note ?? null,
      });
    });
    return this.changeResult(actor.branchId, id, movementId);
  }

  async movements(branchId: number, id: number, limit: number, cursor: string | undefined) {
    if (!(await repo.productExists(this.db, id))) throw new NotFoundError('Product');
    // One extra row tells us whether another page exists.
    const rows = await repo.listMovements(this.db, branchId, id, limit + 1, decodeCursor(cursor));
    const page = rows.slice(0, limit);
    const last = page.at(-1);
    const meta: CursorPageMeta = {
      limit,
      nextCursor: rows.length > limit && last ? encodeCursor({ at: last.createdAt.toISOString(), id: last.id }) : null,
    };
    return { rows: page.map(movementDto), meta };
  }

  private purchaseIn(trx: Executor, actor: Principal, productId: number, input: PurchaseInput): Promise<number> {
    return this.applyMovement(trx, actor, productId, input.quantity, {
      type: 'PURCHASE',
      unitCost: input.unitCost,
      supplierName: input.supplierName ?? null,
      invoiceNo: input.invoiceNo ?? null,
      reason: null,
      note: input.note ?? null,
    });
  }

  /** The one way stock changes: lock → check → update balance → write ledger. */
  private async applyMovement(
    trx: Executor,
    actor: Principal,
    productId: number,
    delta: number,
    m: Pick<Parameters<typeof repo.insertMovement>[1], 'type' | 'unitCost' | 'supplierName' | 'invoiceNo' | 'reason' | 'note'>,
  ): Promise<number> {
    await repo.ensureStockRow(trx, actor.branchId, productId);
    const current = await repo.lockStockQuantity(trx, actor.branchId, productId);
    if (current + delta < 0 && !(await repo.allowNegativeStock(trx))) {
      throw new BusinessRuleError(
        'STOCK_INSUFFICIENT',
        `Only ${current} in stock, so ${-delta} can't be taken out.`,
        { inStock: current },
      );
    }
    await repo.addToStock(trx, actor.branchId, productId, delta);
    return repo.insertMovement(trx, { ...m, branchId: actor.branchId, productId, quantityDelta: delta, createdBy: actor.staffId });
  }

  private async mustBeActive(db: Executor, branchId: number, id: number): Promise<void> {
    const row = await repo.findProduct(db, branchId, id);
    if (!row) throw new NotFoundError('Product');
    if (!row.isActive) throw new BusinessRuleError('PRODUCT_INACTIVE', 'Reactivate this product before changing its stock.');
  }

  private async changeResult(branchId: number, productId: number, movementId: number) {
    const [product, movement] = await Promise.all([this.get(branchId, productId), repo.findMovement(this.db, movementId)]);
    return { product, movement: movementDto(movement) };
  }
}

/** The same name + brand can't be active twice → 409 on the name field. */
async function withDuplicateName<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    const e = error as { code?: string; constraint?: string };
    if (e.code === '23505' && e.constraint === 'products_name_brand_active_uq') {
      throw new ConflictError('DUPLICATE', 'An active product with this name and brand already exists', [
        { field: 'name', message: 'An active product with this name and brand already exists' },
      ]);
    }
    throw error;
  }
}

import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';
import type { StockMovementType } from '../../db/types.js';
import type { CursorKey } from '../../shared/pagination.js';
import type { ListProductsQuery } from './inventory.schemas.js';

export interface ProductRow {
  id: number;
  name: string;
  brand: string | null;
  category: string | null;
  mrp: string;
  defaultDiscountPct: string;
  lastPurchasePrice: string | null;
  stockQuantity: number;
  lowStockThreshold: number;
  isActive: boolean;
  version: number;
}

/** Products with this branch's stock and the latest delivery price. */
function selectProducts(db: Executor, branchId: number) {
  return db
    .selectFrom('products as p')
    .leftJoin('product_stock as s', (join) => join.onRef('s.product_id', '=', 'p.id').on('s.branch_id', '=', branchId))
    .select([
      'p.id',
      'p.name',
      'p.brand',
      'p.category',
      'p.mrp',
      'p.default_discount_pct as defaultDiscountPct',
      sql<string | null>`(
        SELECT m.unit_cost FROM stock_movements m
        WHERE m.product_id = p.id AND m.movement_type = 'PURCHASE'
        ORDER BY m.id DESC LIMIT 1
      )`.as('lastPurchasePrice'),
      sql<number>`coalesce(s.quantity, 0)`.as('stockQuantity'),
      sql<number>`coalesce(s.low_stock_threshold, 0)`.as('lowStockThreshold'),
      'p.is_active as isActive',
      'p.version',
    ]);
}

export async function listProducts(
  db: Executor,
  branchId: number,
  q: ListProductsQuery,
): Promise<{ rows: ProductRow[]; total: number }> {
  let query = selectProducts(db, branchId);
  if (q.status !== 'all') query = query.where('p.is_active', '=', q.status === 'active');
  if (q.category) query = query.where(sql`lower(p.category)`, '=', q.category.toLowerCase());
  if (q.lowStock) query = query.where(sql`coalesce(s.quantity, 0)`, '<=', sql`coalesce(s.low_stock_threshold, 0)`);
  if (q.search) {
    const term = `%${q.search.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    query = query.where((eb) => eb.or([eb('p.name', 'ilike', term), eb('p.brand', 'ilike', term)]));
  }
  const [rows, count] = await Promise.all([
    query.orderBy('p.is_active', 'desc').orderBy(sql`lower(p.name)`).orderBy('p.id').limit(q.limit).offset(q.offset).execute(),
    query.clearSelect().select(sql<number>`count(*)::int`.as('n')).executeTakeFirstOrThrow(),
  ]);
  return { rows, total: count.n };
}

export async function findProduct(db: Executor, branchId: number, id: number): Promise<ProductRow | null> {
  return (await selectProducts(db, branchId).where('p.id', '=', id).executeTakeFirst()) ?? null;
}

export async function productExists(db: Executor, id: number): Promise<boolean> {
  return Boolean(await db.selectFrom('products').select('id').where('id', '=', id).executeTakeFirst());
}

export async function suggestions(db: Executor): Promise<{ categories: string[]; brands: string[] }> {
  const distinct = async (column: 'category' | 'brand') =>
    (
      await db
        .selectFrom('products')
        // One per case-insensitive name, spelled as first entered.
        .select(sql<string>`(array_agg(${sql.ref(column)} ORDER BY id))[1]`.as('v'))
        .where(column, 'is not', null)
        .where('is_active', '=', true)
        .groupBy(sql`lower(${sql.ref(column)})`)
        .orderBy(sql`lower(${sql.ref(column)})`)
        .execute()
    ).map((r) => r.v);
  const [categories, brands] = await Promise.all([distinct('category'), distinct('brand')]);
  return { categories, brands };
}

export async function insertProduct(
  db: Executor,
  v: { name: string; brand: string | null; category: string | null; mrp: string; defaultDiscountPct: string },
): Promise<number> {
  const row = await db
    .insertInto('products')
    .values({ name: v.name, brand: v.brand, category: v.category, mrp: v.mrp, default_discount_pct: v.defaultDiscountPct })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

export async function updateProductIfVersion(
  db: Executor,
  id: number,
  expectedVersion: number,
  changes: Partial<{ name: string; brand: string | null; category: string | null; mrp: string; default_discount_pct: string }>,
): Promise<boolean> {
  const result = await db
    .updateTable('products')
    .set({ ...changes, version: sql`version + 1` })
    .where('id', '=', id)
    .where('version', '=', expectedVersion)
    .executeTakeFirst();
  return result.numUpdatedRows > 0n;
}

export async function setProductActive(db: Executor, id: number, active: boolean): Promise<void> {
  await db
    .updateTable('products')
    .set({ is_active: active, version: sql`version + 1` })
    .where('id', '=', id)
    .execute();
}

/** Creates the branch's stock row if missing (quantity 0). */
export async function ensureStockRow(db: Executor, branchId: number, productId: number): Promise<void> {
  await db
    .insertInto('product_stock')
    .values({ branch_id: branchId, product_id: productId })
    .onConflict((oc) => oc.columns(['branch_id', 'product_id']).doNothing())
    .execute();
}

export async function setLowStockThreshold(db: Executor, branchId: number, productId: number, threshold: number) {
  await db
    .updateTable('product_stock')
    .set({ low_stock_threshold: threshold })
    .where('branch_id', '=', branchId)
    .where('product_id', '=', productId)
    .execute();
}

/** Locks the stock row so concurrent changes to this product's stock queue up. */
export async function lockStockQuantity(db: Executor, branchId: number, productId: number): Promise<number> {
  const row = await db
    .selectFrom('product_stock')
    .select('quantity')
    .where('branch_id', '=', branchId)
    .where('product_id', '=', productId)
    .forUpdate()
    .executeTakeFirstOrThrow();
  return row.quantity;
}

export async function addToStock(db: Executor, branchId: number, productId: number, delta: number): Promise<void> {
  await db
    .updateTable('product_stock')
    .set({ quantity: sql`quantity + ${delta}`, version: sql`version + 1` })
    .where('branch_id', '=', branchId)
    .where('product_id', '=', productId)
    .execute();
}

export async function insertMovement(
  db: Executor,
  m: {
    branchId: number;
    productId: number;
    type: StockMovementType;
    quantityDelta: number;
    unitCost: string | null;
    supplierName: string | null;
    invoiceNo: string | null;
    reason: string | null;
    note: string | null;
    createdBy: number;
  },
): Promise<number> {
  const row = await db
    .insertInto('stock_movements')
    .values({
      branch_id: m.branchId,
      product_id: m.productId,
      movement_type: m.type,
      quantity_delta: m.quantityDelta,
      unit_cost: m.unitCost,
      supplier_name: m.supplierName,
      supplier_invoice_no: m.invoiceNo,
      reason: m.reason,
      note: m.note,
      created_by: m.createdBy,
    })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

export interface MovementRow {
  id: number;
  type: StockMovementType;
  quantityDelta: number;
  unitCost: string | null;
  supplierName: string | null;
  invoiceNo: string | null;
  reason: string | null;
  note: string | null;
  createdBy: string;
  createdAt: Date;
}

function selectMovements(db: Executor) {
  return db
    .selectFrom('stock_movements as m')
    .innerJoin('staff as st', 'st.id', 'm.created_by')
    .select([
      'm.id',
      'm.movement_type as type',
      'm.quantity_delta as quantityDelta',
      'm.unit_cost as unitCost',
      'm.supplier_name as supplierName',
      'm.supplier_invoice_no as invoiceNo',
      'm.reason',
      'm.note',
      'st.full_name as createdBy',
      'm.created_at as createdAt',
    ]);
}

export async function findMovement(db: Executor, id: number): Promise<MovementRow> {
  return selectMovements(db).where('m.id', '=', id).executeTakeFirstOrThrow();
}

/**
 * Newest first. Keyset pagination on the id, which only grows in insert
 * order (timestamps lose microseconds on the way to JavaScript, so paging
 * by time could skip rows).
 */
export async function listMovements(
  db: Executor,
  branchId: number,
  productId: number,
  limit: number,
  after: CursorKey | null,
): Promise<MovementRow[]> {
  let query = selectMovements(db).where('m.branch_id', '=', branchId).where('m.product_id', '=', productId);
  if (after) query = query.where('m.id', '<', after.id);
  return query.orderBy('m.id', 'desc').limit(limit).execute();
}

export async function allowNegativeStock(db: Executor): Promise<boolean> {
  const row = await db.selectFrom('settings').select('allow_negative_stock').executeTakeFirstOrThrow();
  return row.allow_negative_stock;
}

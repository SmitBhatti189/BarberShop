import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { sql } from 'kysely';
import { sellingPrice } from '../../src/modules/inventory/inventory.service.js';
import { SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { createTestContext, type TestContext } from '../helpers/test-context.js';

let ctx: TestContext;
let token: string;

function api(method: 'GET' | 'POST' | 'PATCH', url: string, payload?: object, as = token) {
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: { authorization: `Bearer ${as}` }, payload });
}

async function createProduct(overrides: Record<string, unknown> = {}) {
  const res = await api('POST', '/products', { name: 'Shampoo', mrp: 2000, defaultDiscountPct: 10, ...overrides });
  expect(res.statusCode, res.body).toBe(201);
  return res.json().data;
}

async function stockOf(id: number): Promise<number> {
  return (await api('GET', `/products/${id}`)).json().data.stockQuantity;
}

beforeAll(async () => {
  ctx = await createTestContext();
});

beforeEach(async () => {
  await ctx.db.deleteFrom('stock_movements').execute();
  await ctx.db.deleteFrom('product_stock').execute();
  await ctx.db.deleteFrom('products').execute();
  await ctx.db.updateTable('settings').set({ allow_negative_stock: false }).execute();
  ({ token } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER }));
});

afterAll(async () => {
  await ctx?.close();
});

describe('selling price (MRP less default discount)', () => {
  it('follows the owner example and rounds to the paisa', () => {
    expect(sellingPrice('2000.00', '10.00')).toBe('1800.00');
    expect(sellingPrice('99.99', '12.50')).toBe('87.49'); // 12.49875 discount → 12.50
    expect(sellingPrice('250.00', '0.00')).toBe('250.00');
    expect(sellingPrice('250.00', '100.00')).toBe('0.00');
  });
});

describe('permissions', () => {
  it('needs inventory.view to read and inventory.manage to change', async () => {
    const { token: staff } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    expect((await api('GET', '/products', undefined, staff)).statusCode).toBe(403);
    expect((await api('POST', '/products', { name: 'X', mrp: 10 }, staff)).statusCode).toBe(403);
    expect((await api('GET', '/products')).statusCode).toBe(200);
  });
});

describe('products', () => {
  it('creates a product with opening stock recorded as its first delivery', async () => {
    const p = await createProduct({
      brand: "L'Oréal",
      category: 'Shampoo',
      lowStockThreshold: 3,
      openingStock: { quantity: 12, unitCost: '1600', supplierName: 'Sharma Traders', invoiceNo: 'INV-77' },
    });
    expect(p).toMatchObject({
      name: 'Shampoo',
      brand: "L'Oréal",
      category: 'Shampoo',
      mrp: '2000.00',
      defaultDiscountPct: '10.00',
      sellingPrice: '1800.00',
      lastPurchasePrice: '1600.00',
      stockQuantity: 12,
      lowStockThreshold: 3,
      isLowStock: false,
      isActive: true,
    });
    const history = (await api('GET', `/products/${p.id}/movements`)).json().data;
    expect(history).toHaveLength(1);
    expect(history[0]).toMatchObject({
      type: 'PURCHASE',
      quantityDelta: 12,
      unitCost: '1600.00',
      supplierName: 'Sharma Traders',
      invoiceNo: 'INV-77',
      note: 'Opening stock',
    });
  });

  it('creates a product with no stock', async () => {
    const p = await createProduct();
    expect(p).toMatchObject({ stockQuantity: 0, lastPurchasePrice: null, isLowStock: true });
  });

  it('validates prices, discount and quantities', async () => {
    const res = await api('POST', '/products', {
      name: '',
      mrp: 0,
      defaultDiscountPct: 101,
      openingStock: { quantity: 0, unitCost: '12.345' },
    });
    expect(res.statusCode).toBe(400);
    const fields = res.json().error.details.map((d: { field: string }) => d.field).sort();
    expect(fields).toEqual([
      'body.defaultDiscountPct',
      'body.mrp',
      'body.name',
      'body.openingStock.quantity',
      'body.openingStock.unitCost',
    ]);
  });

  it('blocks the same name and brand twice while active', async () => {
    const first = await createProduct({ name: 'Hair Gel', brand: 'Set Wet' });
    const dup = await api('POST', '/products', { name: 'hair gel', brand: 'SET WET', mrp: 100 });
    expect(dup.statusCode).toBe(409);
    expect(dup.json().error.details[0].field).toBe('name');

    await createProduct({ name: 'Hair Gel', brand: 'Gatsby' }); // other brand is fine

    await api('POST', `/products/${first.id}/deactivate`);
    const again = await createProduct({ name: 'Hair Gel', brand: 'Set Wet' }); // allowed once the old one is inactive
    expect(again.id).not.toBe(first.id);
    expect((await api('POST', `/products/${first.id}/activate`)).statusCode).toBe(409); // two active copies not allowed
  });

  it('edits with the current version and refuses a stale one', async () => {
    const p = await createProduct();
    const res = await api('PATCH', `/products/${p.id}`, { version: 1, mrp: '2200', defaultDiscountPct: '5', lowStockThreshold: 4 });
    expect(res.json().data).toMatchObject({ mrp: '2200.00', sellingPrice: '2090.00', lowStockThreshold: 4, version: 2 });
    const stale = await api('PATCH', `/products/${p.id}`, { version: 1, name: 'Lost' });
    expect(stale.statusCode).toBe(409);
    expect(stale.json().error.code).toBe('STALE');
  });

  it('lists with search, category, status and low-stock filters, and suggests names', async () => {
    await createProduct({ name: 'Argan Oil', brand: 'Moroccan', category: 'Hair oil', lowStockThreshold: 5, openingStock: { quantity: 2, unitCost: 100 } });
    await createProduct({ name: 'Beard Wax', brand: 'Beardo', category: 'Wax', lowStockThreshold: 1, openingStock: { quantity: 9, unitCost: 50 } });
    const old = await createProduct({ name: 'Old Gel', category: 'hair OIL' });
    await api('POST', `/products/${old.id}/deactivate`);

    const names = async (q: string) => (await api('GET', `/products?${q}`)).json().data.map((p: { name: string }) => p.name);
    expect(await names('')).toEqual(['Argan Oil', 'Beard Wax']);
    expect(await names('search=beardo')).toEqual(['Beard Wax']);
    expect(await names('category=hair%20oil')).toEqual(['Argan Oil']);
    expect(await names('lowStock=true')).toEqual(['Argan Oil']);
    expect(await names('status=inactive')).toEqual(['Old Gel']);

    const s = (await api('GET', '/products/suggestions')).json().data;
    expect(s.categories).toEqual(['Hair oil', 'Wax']); // inactive products' categories left out
    expect(s.brands).toEqual(['Beardo', 'Moroccan']);
  });
});

describe('stock', () => {
  it('adds deliveries and keeps each lot price in history', async () => {
    const p = await createProduct({ openingStock: { quantity: 5, unitCost: 1600 } });
    const res = await api('POST', `/products/${p.id}/purchases`, { quantity: 10, unitCost: '1550.50', supplierName: 'New Supplier' });
    expect(res.statusCode).toBe(201);
    expect(res.json().data.product).toMatchObject({ stockQuantity: 15, lastPurchasePrice: '1550.50', mrp: '2000.00' });
    expect(res.json().data.movement).toMatchObject({ type: 'PURCHASE', quantityDelta: 10, unitCost: '1550.50' });
  });

  it('adjusts out with a reason and never below zero', async () => {
    const p = await createProduct({ openingStock: { quantity: 3, unitCost: 100 } });
    const tooMany = await api('POST', `/products/${p.id}/adjustments`, { direction: 'OUT', quantity: 4, reason: 'DAMAGED' });
    expect(tooMany.statusCode).toBe(422);
    expect(tooMany.json().error).toMatchObject({ code: 'STOCK_INSUFFICIENT', details: { inStock: 3 } });

    const ok = await api('POST', `/products/${p.id}/adjustments`, { direction: 'OUT', quantity: 2, reason: 'USED_IN_SALON' });
    expect(ok.json().data.product.stockQuantity).toBe(1);
    expect(ok.json().data.movement).toMatchObject({ type: 'ADJUSTMENT', quantityDelta: -2, reason: 'USED_IN_SALON' });

    const noNote = await api('POST', `/products/${p.id}/adjustments`, { direction: 'IN', quantity: 1, reason: 'OTHER' });
    expect(noNote.statusCode).toBe(400);
  });

  it('allows negative stock only when the setting is on', async () => {
    const p = await createProduct();
    await ctx.db.updateTable('settings').set({ allow_negative_stock: true }).execute();
    const res = await api('POST', `/products/${p.id}/adjustments`, { direction: 'OUT', quantity: 2, reason: 'COUNT_CORRECTION' });
    expect(res.json().data.product.stockQuantity).toBe(-2);
  });

  it('refuses stock changes on an inactive product', async () => {
    const p = await createProduct();
    await api('POST', `/products/${p.id}/deactivate`);
    const res = await api('POST', `/products/${p.id}/purchases`, { quantity: 1, unitCost: 10 });
    expect(res.json().error.code).toBe('PRODUCT_INACTIVE');
  });

  it('pages history newest first', async () => {
    const p = await createProduct({ openingStock: { quantity: 1, unitCost: 1 } });
    for (let i = 2; i <= 5; i++) await api('POST', `/products/${p.id}/purchases`, { quantity: i, unitCost: 1 });

    const first = (await api('GET', `/products/${p.id}/movements?limit=2`)).json();
    expect(first.data.map((m: { quantityDelta: number }) => m.quantityDelta)).toEqual([5, 4]);
    const second = (await api('GET', `/products/${p.id}/movements?limit=2&cursor=${first.meta.nextCursor}`)).json();
    expect(second.data.map((m: { quantityDelta: number }) => m.quantityDelta)).toEqual([3, 2]);
    const last = (await api('GET', `/products/${p.id}/movements?limit=2&cursor=${second.meta.nextCursor}`)).json();
    expect(last.data.map((m: { quantityDelta: number }) => m.quantityDelta)).toEqual([1]);
    expect(last.meta.nextCursor).toBeNull();
  });

  it('never oversells when 20 people take stock at once', async () => {
    const p = await createProduct({ openingStock: { quantity: 10, unitCost: 100 } });
    const results = await Promise.all(
      Array.from({ length: 20 }, () =>
        api('POST', `/products/${p.id}/adjustments`, { direction: 'OUT', quantity: 1, reason: 'USED_IN_SALON' }),
      ),
    );
    const codes = results.map((r) => r.statusCode);
    expect(codes.filter((c) => c === 201)).toHaveLength(10);
    expect(codes.filter((c) => c === 422)).toHaveLength(10);
    expect(await stockOf(p.id)).toBe(0);

    // The balance always equals the sum of the ledger.
    const ledger = await ctx.db
      .selectFrom('stock_movements')
      .select(sql<number>`sum(quantity_delta)::int`.as('total'))
      .where('product_id', '=', p.id)
      .executeTakeFirstOrThrow();
    expect(ledger.total).toBe(0);
  });
});

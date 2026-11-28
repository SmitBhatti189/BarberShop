import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { createTestContext, type TestContext } from '../helpers/test-context.js';

let ctx: TestContext;
let token: string;
let haircutId: number;
let beardId: number;
let gelId: number;

function api(method: 'GET' | 'PUT' | 'POST', url: string, payload?: object, as = token) {
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: { authorization: `Bearer ${as}` }, payload });
}

async function employee(name: string): Promise<number> {
  const role = await ctx.db.selectFrom('roles').select('id').where('name', '=', SYSTEM_ROLES.STAFF).executeTakeFirstOrThrow();
  const branch = await ctx.db.selectFrom('branches').select('id').executeTakeFirstOrThrow();
  const row = await ctx.db
    .insertInto('staff')
    .values({ branch_id: branch.id, role_id: role.id, full_name: name })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

const item = (pay: { services: { itemId: number }[]; products: { itemId: number }[] }, type: 'services' | 'products', id: number) =>
  (pay[type] as { itemId: number; ratePct: string | null; effectiveRatePct: string | null; source: string }[]).find(
    (i) => i.itemId === id,
  )!;

beforeAll(async () => {
  ctx = await createTestContext();
});

beforeEach(async () => {
  await ctx.db.deleteFrom('commission_rules').execute();
  await ctx.db.deleteFrom('staff_compensation').execute();
  await ctx.db.deleteFrom('stock_movements').execute();
  await ctx.db.deleteFrom('product_stock').execute();
  await ctx.db.deleteFrom('products').execute();
  await ctx.db.deleteFrom('services').execute();
  await ctx.db.updateTable('settings').set({ default_commission_pct: '10.00' }).execute();
  ({ token } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER }));
  const svc = async (name: string, price: string) =>
    (await api('POST', '/services', { name, price, durationMinutes: 30 })).json().data.id as number;
  haircutId = await svc('Haircut', '200');
  beardId = await svc('Beard Trim', '100');
  gelId = (await api('POST', '/products', { name: 'Hair Gel', mrp: 200, defaultDiscountPct: 10 })).json().data.id;
});

afterAll(async () => {
  await ctx?.close();
});

describe('permissions and salon default', () => {
  it('only pay managers can see and change pay', async () => {
    const { token: staff } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    expect((await api('GET', '/compensation/staff', undefined, staff)).statusCode).toBe(403);
    expect((await api('PUT', '/compensation/default', { defaultCommissionPct: 5 }, staff)).statusCode).toBe(403);
  });

  it('reads and sets the salon default', async () => {
    expect((await api('GET', '/compensation/default')).json().data.defaultCommissionPct).toBe('10.00');
    const res = await api('PUT', '/compensation/default', { defaultCommissionPct: '12.5' });
    expect(res.json().data.defaultCommissionPct).toBe('12.50');
    expect((await api('PUT', '/compensation/default', { defaultCommissionPct: 101 })).statusCode).toBe(400);
  });
});

describe('effective rates on the pay page', () => {
  it('commission-based: own rate wins, otherwise the salon default', async () => {
    const id = await employee('Asha');
    await api('PUT', `/compensation/staff/${id}`, {
      monthlySalary: null,
      rates: [{ itemType: 'SERVICE', itemId: haircutId, ratePct: 40 }],
    });
    const pay = (await api('GET', `/compensation/staff/${id}`)).json().data;
    expect(pay.monthlySalary).toBeNull();
    expect(item(pay, 'services', haircutId)).toMatchObject({ ratePct: '40.00', effectiveRatePct: '40.00', source: 'SPECIFIC' });
    expect(item(pay, 'services', beardId)).toMatchObject({ ratePct: null, effectiveRatePct: '10.00', source: 'DEFAULT' });
    expect(item(pay, 'products', gelId)).toMatchObject({ source: 'DEFAULT' });
    expect(item(pay, 'products', gelId)).toMatchObject({ itemId: gelId }); // price is the selling price
    expect(pay.products[0].price).toBe('180.00');
  });

  it('salaried: no commission unless a rate is set', async () => {
    const id = await employee('Imran');
    const res = await api('PUT', `/compensation/staff/${id}`, {
      monthlySalary: '15000',
      rates: [{ itemType: 'PRODUCT', itemId: gelId, ratePct: 5 }],
    });
    const pay = res.json().data;
    expect(pay.monthlySalary).toBe('15000.00');
    expect(item(pay, 'services', haircutId)).toMatchObject({ effectiveRatePct: null, source: 'NONE' });
    expect(item(pay, 'products', gelId)).toMatchObject({ effectiveRatePct: '5.00', source: 'SPECIFIC' });
  });
});

describe('saving pay keeps history', () => {
  it('changing a salary closes the old one; clearing it makes the employee commission-based', async () => {
    const id = await employee('Vikram');
    await api('PUT', `/compensation/staff/${id}`, { monthlySalary: '12000', rates: [] });
    await api('PUT', `/compensation/staff/${id}`, { monthlySalary: '14000', rates: [] });
    await api('PUT', `/compensation/staff/${id}`, { monthlySalary: '14000.00', rates: [] }); // same value: no new row
    const cleared = await api('PUT', `/compensation/staff/${id}`, { monthlySalary: null, rates: [] });
    expect(cleared.json().data.monthlySalary).toBeNull();

    const rows = await ctx.db
      .selectFrom('staff_compensation')
      .select(['monthly_salary', 'effective_to'])
      .where('staff_id', '=', id)
      .orderBy('id')
      .execute();
    expect(rows.map((r) => r.monthly_salary)).toEqual(['12000.00', '14000.00']);
    expect(rows.every((r) => r.effective_to !== null)).toBe(true);
  });

  it('changes, keeps and removes rates, writing history only on real changes', async () => {
    const id = await employee('Rahul');
    const save = (ratePct: number | string | null) =>
      api('PUT', `/compensation/staff/${id}`, { monthlySalary: null, rates: [{ itemType: 'SERVICE', itemId: haircutId, ratePct }] });
    await save(40);
    await save('40.00'); // unchanged
    await save(35);
    await save(null); // removed → salon default applies again

    const rules = await ctx.db
      .selectFrom('commission_rules')
      .select(['rate_pct', 'effective_to'])
      .where('staff_id', '=', id)
      .orderBy('id')
      .execute();
    expect(rules.map((r) => r.rate_pct)).toEqual(['40.00', '35.00']);
    expect(rules.every((r) => r.effective_to !== null)).toBe(true);

    const pay = (await api('GET', `/compensation/staff/${id}`)).json().data;
    expect(item(pay, 'services', haircutId)).toMatchObject({ ratePct: null, source: 'DEFAULT' });
  });

  it('leaves items that are not in the request untouched', async () => {
    const id = await employee('Neha');
    await api('PUT', `/compensation/staff/${id}`, {
      monthlySalary: null,
      rates: [
        { itemType: 'SERVICE', itemId: haircutId, ratePct: 40 },
        { itemType: 'SERVICE', itemId: beardId, ratePct: 30 },
      ],
    });
    await api('PUT', `/compensation/staff/${id}`, { monthlySalary: null, rates: [{ itemType: 'SERVICE', itemId: beardId, ratePct: 25 }] });
    const pay = (await api('GET', `/compensation/staff/${id}`)).json().data;
    expect(item(pay, 'services', haircutId).ratePct).toBe('40.00');
    expect(item(pay, 'services', beardId).ratePct).toBe('25.00');
  });

  it('refuses inactive items, inactive employees and bad input', async () => {
    const id = await employee('Deepak');
    await api('POST', `/services/${beardId}/deactivate`);
    const inactiveItem = await api('PUT', `/compensation/staff/${id}`, {
      monthlySalary: null,
      rates: [{ itemType: 'SERVICE', itemId: beardId, ratePct: 10 }],
    });
    expect(inactiveItem.json().error.code).toBe('ITEM_NOT_AVAILABLE');

    const bad = await api('PUT', `/compensation/staff/${id}`, {
      monthlySalary: '0',
      rates: [
        { itemType: 'SERVICE', itemId: haircutId, ratePct: 101 },
        { itemType: 'SERVICE', itemId: haircutId, ratePct: 10 },
      ],
    });
    expect(bad.statusCode).toBe(400);

    await ctx.db.updateTable('staff').set({ is_active: false }).where('id', '=', id).execute();
    const inactiveStaff = await api('PUT', `/compensation/staff/${id}`, { monthlySalary: null, rates: [] });
    expect(inactiveStaff.json().error.code).toBe('STAFF_INACTIVE');
    expect((await api('GET', '/compensation/staff/999999')).statusCode).toBe(404);
  });

  it('two managers saving the same rate at once leave one clean current rate', async () => {
    const id = await employee('Kiran');
    const results = await Promise.all(
      [20, 25, 30, 35].map((rate) =>
        api('PUT', `/compensation/staff/${id}`, { monthlySalary: null, rates: [{ itemType: 'SERVICE', itemId: haircutId, ratePct: rate }] }),
      ),
    );
    expect(results.map((r) => r.statusCode)).toEqual([200, 200, 200, 200]);
    const open = await ctx.db
      .selectFrom('commission_rules')
      .select('rate_pct')
      .where('staff_id', '=', id)
      .where('effective_to', 'is', null)
      .execute();
    expect(open).toHaveLength(1);
    const all = await ctx.db.selectFrom('commission_rules').select('id').where('staff_id', '=', id).execute();
    expect(all).toHaveLength(4); // every change kept in history
  });

  it('lists employees with their pay type', async () => {
    const salaried = await employee('Zara');
    await api('PUT', `/compensation/staff/${salaried}`, {
      monthlySalary: '9000',
      rates: [{ itemType: 'PRODUCT', itemId: gelId, ratePct: 5 }],
    });
    const list = (await api('GET', '/compensation/staff')).json().data as { fullName: string; monthlySalary: string | null; specificRates: number }[];
    expect(list.find((s) => s.fullName === 'Zara')).toMatchObject({ monthlySalary: '9000.00', specificRates: 1 });
  });
});

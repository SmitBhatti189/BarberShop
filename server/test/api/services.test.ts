import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { createTestContext, type TestContext } from '../helpers/test-context.js';

let ctx: TestContext;
let token: string;

function api(method: 'GET' | 'POST' | 'PATCH', url: string, payload?: object, as = token) {
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: { authorization: `Bearer ${as}` }, payload });
}

async function createService(overrides: Record<string, unknown> = {}) {
  const res = await api('POST', '/services', { name: 'Haircut', price: 200, durationMinutes: 30, ...overrides });
  expect(res.statusCode, res.body).toBe(201);
  return res.json().data;
}

beforeAll(async () => {
  ctx = await createTestContext();
});

beforeEach(async () => {
  await ctx.db.deleteFrom('services').execute();
  ({ token } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER }));
});

afterAll(async () => {
  await ctx?.close();
});

describe('services', () => {
  it('lets staff view but only managers change', async () => {
    const { token: staff } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    expect((await api('GET', '/services', undefined, staff)).statusCode).toBe(200); // Staff role has services.view
    expect((await api('POST', '/services', { name: 'X', price: 1, durationMinutes: 5 }, staff)).statusCode).toBe(403);
  });

  it('creates a service with price and duration', async () => {
    const s = await createService({ name: ' Haircut + Beard ', category: 'Combo', description: 'Cut and trim', price: '250' });
    expect(s).toMatchObject({
      name: 'Haircut + Beard',
      category: 'Combo',
      description: 'Cut and trim',
      price: '250.00',
      durationMinutes: 30,
      isActive: true,
      version: 1,
    });
  });

  it('validates fields', async () => {
    const res = await api('POST', '/services', { name: '', price: '12.345', durationMinutes: 0 });
    expect(res.statusCode).toBe(400);
    const fields = res.json().error.details.map((d: { field: string }) => d.field).sort();
    expect(fields).toEqual(['body.durationMinutes', 'body.name', 'body.price']);
  });

  it('allows a free service (price 0)', async () => {
    expect((await createService({ name: 'Consultation', price: 0 })).price).toBe('0.00');
  });

  it('blocks a duplicate active name, ignoring case', async () => {
    const first = await createService({ name: 'Beard Trim' });
    const dup = await api('POST', '/services', { name: 'beard trim', price: 100, durationMinutes: 15 });
    expect(dup.statusCode).toBe(409);
    expect(dup.json().error.details[0].field).toBe('name');

    await api('POST', `/services/${first.id}/deactivate`);
    await createService({ name: 'Beard Trim' }); // allowed once the old one is inactive
    expect((await api('POST', `/services/${first.id}/activate`)).statusCode).toBe(409);
  });

  it('edits with the current version and refuses a stale one', async () => {
    const s = await createService();
    const res = await api('PATCH', `/services/${s.id}`, { version: 1, price: '220', durationMinutes: 35, category: null });
    expect(res.json().data).toMatchObject({ price: '220.00', durationMinutes: 35, category: null, version: 2 });
    const stale = await api('PATCH', `/services/${s.id}`, { version: 1, name: 'Lost' });
    expect(stale.statusCode).toBe(409);
    expect(stale.json().error.code).toBe('STALE');
    expect((await api('PATCH', '/services/999999', { version: 1, name: 'X' })).statusCode).toBe(404);
  });

  it('lists with search, category and status, grouped by category, and lists categories', async () => {
    await createService({ name: 'Haircut', category: 'Hair' });
    await createService({ name: 'Hair Wash', category: 'hair', price: 80, durationMinutes: 15 });
    await createService({ name: 'Beard Trim', category: 'Beard', price: 100, durationMinutes: 15 });
    const old = await createService({ name: 'Old Facial', category: 'Facial' });
    await api('POST', `/services/${old.id}/deactivate`);

    const names = async (q: string) => (await api('GET', `/services?${q}`)).json().data.map((s: { name: string }) => s.name);
    // Grouped by category (Beard before Hair), then alphabetical ("Hair Wash" sorts before "Haircut").
    expect(await names('')).toEqual(['Beard Trim', 'Hair Wash', 'Haircut']);
    expect(await names('search=wash')).toEqual(['Hair Wash']);
    expect(await names('category=HAIR')).toEqual(['Hair Wash', 'Haircut']);
    expect(await names('status=inactive')).toEqual(['Old Facial']);

    expect((await api('GET', '/services/categories')).json().data).toEqual(['Beard', 'Hair']);
  });
});

import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { createTestContext, type TestContext } from '../helpers/test-context.js';

let ctx: TestContext;
let managerToken: string;
let managerRoleId: number;
let staffRoleId: number;
let counter = 0;

/** A unique valid Indian mobile per call. */
const nextMobile = () => `98${String(10_000_000 + ++counter).slice(-8)}`;

function api(method: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE', url: string, token = managerToken, payload?: object) {
  return ctx.app.inject({ method, url: `/api/v1${url}`, headers: { authorization: `Bearer ${token}` }, payload });
}

async function createEmployee(overrides: Record<string, unknown> = {}) {
  const res = await api('POST', '/staff', managerToken, {
    fullName: `Employee ${++counter}`,
    roleId: staffRoleId,
    ...overrides,
  });
  expect(res.statusCode, res.body).toBe(201);
  return res.json().data;
}

async function login(username: string, password: string) {
  return ctx.app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username, password } });
}

beforeAll(async () => {
  ctx = await createTestContext();
  const roles = await ctx.db.selectFrom('roles').select(['id', 'name']).execute();
  managerRoleId = roles.find((r) => r.name === SYSTEM_ROLES.MANAGER)!.id;
  staffRoleId = roles.find((r) => r.name === SYSTEM_ROLES.STAFF)!.id;
});

beforeEach(async () => {
  // Fresh staff table per test so manager counts are predictable.
  await ctx.db.deleteFrom('auth_sessions').execute();
  await ctx.db.deleteFrom('staff').execute();
  ({ token: managerToken } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER }));
});

afterAll(async () => {
  await ctx?.close();
});

describe('permissions', () => {
  it('lets the manager list staff and refuses staff without staff.view', async () => {
    expect((await api('GET', '/staff')).statusCode).toBe(200);
    const { token } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    expect((await api('GET', '/staff', token)).statusCode).toBe(403);
    expect((await api('POST', '/staff', token, { fullName: 'X', roleId: staffRoleId })).statusCode).toBe(403);
  });

  it('lists roles for the employee form', async () => {
    const res = await api('GET', '/roles');
    expect(res.statusCode).toBe(200);
    expect(res.json().data.map((r: { name: string }) => r.name)).toEqual(expect.arrayContaining(['Manager', 'Staff']));
    const { token } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    expect((await api('GET', '/roles', token)).statusCode).toBe(403);
  });
});

describe('creating employees', () => {
  it('creates an employee with a login and never returns the password', async () => {
    const created = await createEmployee({
      fullName: '  Rahul Sharma ',
      mobile: '+91 98765-43210',
      email: 'Rahul@Example.com',
      joinedOn: '2026-01-15',
      login: { username: 'rahul', password: 'secret-pass-1' },
    });
    expect(created).toMatchObject({
      fullName: 'Rahul Sharma',
      mobile: '9876543210',
      email: 'rahul@example.com',
      roleName: 'Staff',
      isActive: true,
      performsServices: true,
      joinedOn: '2026-01-15',
      username: 'rahul',
      version: 1,
    });
    expect(JSON.stringify(created)).not.toMatch(/password|hash/i);
    expect((await login('rahul', 'secret-pass-1')).statusCode).toBe(200);
  });

  it('creates an employee without a login', async () => {
    const created = await createEmployee({ performsServices: false });
    expect(created.username).toBeNull();
    expect(created.performsServices).toBe(false);
  });

  it('rejects invalid input with field messages', async () => {
    const res = await api('POST', '/staff', managerToken, {
      fullName: '',
      mobile: '12345',
      roleId: staffRoleId,
      joinedOn: '2999-01-01',
      login: { username: 'a', password: 'short' },
    });
    expect(res.statusCode).toBe(400);
    const fields = res.json().error.details.map((d: { field: string }) => d.field).sort();
    expect(fields).toEqual(['body.fullName', 'body.joinedOn', 'body.login.password', 'body.login.username', 'body.mobile']);
  });

  it('rejects an unknown role', async () => {
    const res = await api('POST', '/staff', managerToken, { fullName: 'X', roleId: 999_999 });
    expect(res.statusCode).toBe(400);
    expect(res.json().error.details[0].field).toBe('roleId');
  });

  it('names the field when a mobile or username is already used', async () => {
    const mobile = nextMobile();
    await createEmployee({ mobile, login: { username: 'asha', password: 'secret-pass-1' } });

    const dupMobile = await api('POST', '/staff', managerToken, { fullName: 'B', roleId: staffRoleId, mobile });
    expect(dupMobile.statusCode).toBe(409);
    expect(dupMobile.json().error.details[0].field).toBe('mobile');

    const dupUser = await api('POST', '/staff', managerToken, {
      fullName: 'C',
      roleId: staffRoleId,
      login: { username: 'ASHA', password: 'secret-pass-1' },
    });
    expect(dupUser.statusCode).toBe(409);
    expect(dupUser.json().error.details[0].field).toBe('username');
  });
});

describe('listing', () => {
  it('searches by name or mobile, filters by status and pages', async () => {
    await createEmployee({ fullName: 'Asha Rao', mobile: '9811111111' });
    const vikram = await createEmployee({ fullName: 'Vikram Singh', mobile: '9822222222' });
    await api('POST', `/staff/${vikram.id}/deactivate`);

    const byName = (await api('GET', '/staff?search=asha')).json();
    expect(byName.data.map((s: { fullName: string }) => s.fullName)).toEqual(['Asha Rao']);

    const byMobile = (await api('GET', '/staff?search=98111')).json();
    expect(byMobile.data).toHaveLength(1);

    const inactive = (await api('GET', '/staff?status=inactive')).json();
    expect(inactive.data.map((s: { fullName: string }) => s.fullName)).toEqual(['Vikram Singh']);

    const page = (await api('GET', '/staff?status=all&limit=1&offset=0')).json();
    expect(page.data).toHaveLength(1);
    expect(page.meta).toEqual({ limit: 1, offset: 0, total: 3 }); // incl. the test manager
  });
});

describe('editing', () => {
  it('saves with the current version and refuses a stale one', async () => {
    const e = await createEmployee();
    const saved = await api('PATCH', `/staff/${e.id}`, managerToken, { version: 1, fullName: 'Renamed' });
    expect(saved.statusCode).toBe(200);
    expect(saved.json().data).toMatchObject({ fullName: 'Renamed', version: 2 });

    const stale = await api('PATCH', `/staff/${e.id}`, managerToken, { version: 1, fullName: 'Lost update' });
    expect(stale.statusCode).toBe(409);
    expect(stale.json().error.code).toBe('STALE');
  });

  it('can clear optional fields', async () => {
    const e = await createEmployee({ mobile: nextMobile(), email: 'x@example.com' });
    const res = await api('PATCH', `/staff/${e.id}`, managerToken, { version: 1, mobile: null, email: null });
    expect(res.json().data).toMatchObject({ mobile: null, email: null });
  });

  it('returns 404 for a missing employee', async () => {
    expect((await api('PATCH', '/staff/999999', managerToken, { version: 1, fullName: 'X' })).statusCode).toBe(404);
  });
});

describe('activation and logins', () => {
  it('refuses to deactivate yourself or remove your own login', async () => {
    const me = await api('GET', '/auth/me');
    const myId = me.json().data.id;
    expect((await api('POST', `/staff/${myId}/deactivate`)).json().error.code).toBe('CANNOT_DEACTIVATE_SELF');
    expect((await api('DELETE', `/staff/${myId}/login`)).json().error.code).toBe('CANNOT_REMOVE_OWN_LOGIN');
  });

  it('signs a deactivated employee out immediately and lets them back in when reactivated', async () => {
    const e = await createEmployee({ login: { username: 'meena', password: 'secret-pass-1' } });
    const token = (await login('meena', 'secret-pass-1')).json().data.accessToken;
    expect((await api('GET', '/auth/me', token)).statusCode).toBe(200);

    const off = await api('POST', `/staff/${e.id}/deactivate`);
    expect(off.json().data.isActive).toBe(false);
    expect((await api('GET', '/auth/me', token)).statusCode).toBe(401);
    expect((await login('meena', 'secret-pass-1')).statusCode).toBe(401);

    await api('POST', `/staff/${e.id}/activate`);
    expect((await login('meena', 'secret-pass-1')).statusCode).toBe(200);
  });

  it('changes a password, ending old sessions', async () => {
    const e = await createEmployee({ login: { username: 'kiran', password: 'old-password-1' } });
    const oldToken = (await login('kiran', 'old-password-1')).json().data.accessToken;

    const res = await api('PUT', `/staff/${e.id}/login`, managerToken, { username: 'kiran', password: 'new-password-1' });
    expect(res.statusCode).toBe(200);
    expect((await api('GET', '/auth/me', oldToken)).statusCode).toBe(401);
    expect((await login('kiran', 'old-password-1')).statusCode).toBe(401);
    expect((await login('kiran', 'new-password-1')).statusCode).toBe(200);
  });

  it('removes a login', async () => {
    const e = await createEmployee({ login: { username: 'deepa', password: 'secret-pass-1' } });
    const res = await api('DELETE', `/staff/${e.id}/login`);
    expect(res.json().data.username).toBeNull();
    expect((await login('deepa', 'secret-pass-1')).statusCode).toBe(401);
  });
});

describe('the salon always keeps a manager who can sign in', () => {
  const managerLogin = (username: string) => ({ roleId: managerRoleId, login: { username, password: 'secret-pass-1' } });

  it('blocks deactivating, demoting or removing the login of the last one', async () => {
    const only = await createEmployee(managerLogin('owner1'));
    expect((await api('POST', `/staff/${only.id}/deactivate`)).json().error.code).toBe('LAST_MANAGER');
    expect((await api('DELETE', `/staff/${only.id}/login`)).json().error.code).toBe('LAST_MANAGER');
    const demote = await api('PATCH', `/staff/${only.id}`, managerToken, { version: 1, roleId: staffRoleId });
    expect(demote.json().error.code).toBe('LAST_MANAGER');

    await createEmployee(managerLogin('owner2'));
    expect((await api('POST', `/staff/${only.id}/deactivate`)).statusCode).toBe(200);
  });

  it('lets only one of two simultaneous deactivations through', async () => {
    const a = await createEmployee(managerLogin('mgr-a'));
    const b = await createEmployee(managerLogin('mgr-b'));
    const results = await Promise.all([api('POST', `/staff/${a.id}/deactivate`), api('POST', `/staff/${b.id}/deactivate`)]);
    expect(results.map((r) => r.statusCode).sort()).toEqual([200, 422]);
    const stillActive = await ctx.db
      .selectFrom('staff')
      .select('id')
      .where('id', 'in', [a.id, b.id])
      .where('is_active', '=', true)
      .execute();
    expect(stillActive).toHaveLength(1);
  });
});

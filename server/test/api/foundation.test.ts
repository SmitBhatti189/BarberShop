import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { z } from 'zod';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { requirePermission } from '../../src/plugins/auth.js';
import { BusinessRuleError } from '../../src/shared/errors.js';
import { PERMISSIONS, SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { createTestContext, type TestContext } from '../helpers/test-context.js';

let ctx: TestContext;

beforeAll(async () => {
  ctx = await createTestContext((app) => {
    // Throw-away routes that exercise the shared plumbing.
    const api = app.withTypeProvider<ZodTypeProvider>();
    api.get('/api/v1/__test/settings', { preHandler: requirePermission(app, PERMISSIONS.SETTINGS_MANAGE) }, async () => ({
      data: 'secret',
    }));
    api.post(
      '/api/v1/__test/echo',
      { schema: { body: z.object({ name: z.string().min(2), qty: z.number().int().positive() }) } },
      async (request) => ({ data: request.body }),
    );
    api.get('/api/v1/__test/rule', async () => {
      throw new BusinessRuleError('STOCK_INSUFFICIENT', 'Not enough stock');
    });
    api.get('/api/v1/__test/crash', async () => {
      throw new Error('database password is hunter2');
    });
  });
});

afterAll(async () => {
  await ctx.close();
});

describe('health', () => {
  it('reports the database as up', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/v1/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json().data).toMatchObject({ status: 'ok', database: 'up' });
  });
});

describe('error envelope', () => {
  it('returns 404 for unknown routes', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/v1/nope' });
    expect(res.statusCode).toBe(404);
    expect(res.json().error.code).toBe('NOT_FOUND');
  });

  it('returns 400 with field details for invalid bodies', async () => {
    const res = await ctx.app.inject({ method: 'POST', url: '/api/v1/__test/echo', payload: { name: 'a', qty: -1 } });
    expect(res.statusCode).toBe(400);
    const { error } = res.json();
    expect(error.code).toBe('VALIDATION_ERROR');
    expect(error.details.map((d: { field: string }) => d.field).sort()).toEqual(['body.name', 'body.qty']);
  });

  it('maps business-rule errors to 422', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/v1/__test/rule' });
    expect(res.statusCode).toBe(422);
    expect(res.json()).toEqual({ error: { code: 'STOCK_INSUFFICIENT', message: 'Not enough stock' } });
  });

  it('never leaks internal error messages', async () => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/v1/__test/crash' });
    expect(res.statusCode).toBe(500);
    expect(res.body).not.toContain('hunter2');
    expect(res.json().error.code).toBe('INTERNAL_ERROR');
  });
});

describe('authentication and permission guard', () => {
  const url = '/api/v1/__test/settings';

  it('rejects requests without a token', async () => {
    const res = await ctx.app.inject({ method: 'GET', url });
    expect(res.statusCode).toBe(401);
    expect(res.json().error.code).toBe('UNAUTHORIZED');
  });

  it('rejects forged tokens', async () => {
    const res = await ctx.app.inject({ method: 'GET', url, headers: { authorization: 'Bearer abc.def.ghi' } });
    expect(res.statusCode).toBe(401);
  });

  it('forbids staff without the permission', async () => {
    const { token } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    const res = await ctx.app.inject({ method: 'GET', url, headers: { authorization: `Bearer ${token}` } });
    expect(res.statusCode).toBe(403);
    expect(res.json().error.code).toBe('FORBIDDEN');
  });

  it('allows the manager', async () => {
    const { token } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER });
    const res = await ctx.app.inject({ method: 'GET', url, headers: { authorization: `Bearer ${token}` } });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ data: 'secret' });
  });

  it('rejects a still-unexpired token once the staff member is deactivated', async () => {
    const { token, staffId } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER });
    await ctx.db.updateTable('staff').set({ is_active: false }).where('id', '=', staffId).execute();
    const res = await ctx.app.inject({ method: 'GET', url, headers: { authorization: `Bearer ${token}` } });
    expect(res.statusCode).toBe(401);
  });

  it('rejects a token whose session was revoked (logout)', async () => {
    const { token, sessionId } = await ctx.createStaff({ role: SYSTEM_ROLES.MANAGER });
    await ctx.db.updateTable('auth_sessions').set({ revoked_at: new Date() }).where('id', '=', sessionId).execute();
    const res = await ctx.app.inject({ method: 'GET', url, headers: { authorization: `Bearer ${token}` } });
    expect(res.statusCode).toBe(401);
  });

  it('applies role permission changes immediately', async () => {
    const { token } = await ctx.createStaff({ role: SYSTEM_ROLES.STAFF });
    const staffRole = await ctx.db.selectFrom('roles').select('id').where('name', '=', SYSTEM_ROLES.STAFF).executeTakeFirstOrThrow();
    const perm = await ctx.db.selectFrom('permissions').select('id').where('key', '=', PERMISSIONS.SETTINGS_MANAGE).executeTakeFirstOrThrow();
    await ctx.db.insertInto('role_permissions').values({ role_id: staffRole.id, permission_id: perm.id }).execute();
    const res = await ctx.app.inject({ method: 'GET', url, headers: { authorization: `Bearer ${token}` } });
    expect(res.statusCode).toBe(200);
  });
});

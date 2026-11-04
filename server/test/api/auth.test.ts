import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { sql } from 'kysely';
import { hashPassword } from '../../src/modules/auth/password.js';
import { PERMISSIONS, SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { createTestContext, type TestContext } from '../helpers/test-context.js';

let ctx: TestContext;
const PASSWORD = 'test-password-1';

async function createLogin(username: string, role: string = SYSTEM_ROLES.STAFF): Promise<number> {
  const roleRow = await ctx.db.selectFrom('roles').select('id').where('name', '=', role).executeTakeFirstOrThrow();
  const branch = await ctx.db.selectFrom('branches').select('id').executeTakeFirstOrThrow();
  const row = await ctx.db
    .insertInto('staff')
    .values({
      branch_id: branch.id,
      role_id: roleRow.id,
      full_name: `User ${username}`,
      username,
      password_hash: await hashPassword(PASSWORD),
    })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

function login(username: string, password = PASSWORD) {
  return ctx.app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username, password } });
}

function refresh(refreshToken: string) {
  return ctx.app.inject({ method: 'POST', url: '/api/v1/auth/refresh', payload: { refreshToken } });
}

beforeAll(async () => {
  ctx = await createTestContext();
});

afterAll(async () => {
  await ctx.close();
});

describe('POST /auth/login', () => {
  it('returns tokens and the caller’s permissions', async () => {
    await createLogin('manager1', SYSTEM_ROLES.MANAGER);
    const res = await login('MANAGER1'); // usernames are case-insensitive
    expect(res.statusCode).toBe(200);
    const { data } = res.json();
    expect(data.accessToken).toBeTypeOf('string');
    expect(data.refreshToken.length).toBeGreaterThan(30);
    expect(data.expiresIn).toBe(900);
    expect(data.user.permissions).toContain(PERMISSIONS.SETTINGS_MANAGE);
  });

  it('never stores the refresh token in plain text', async () => {
    await createLogin('plain1');
    const { data } = (await login('plain1')).json();
    const found = await ctx.db
      .selectFrom('auth_sessions')
      .select('id')
      .where('refresh_token_hash', '=', data.refreshToken)
      .executeTakeFirst();
    expect(found).toBeUndefined();
  });

  it('gives the same error for a wrong password and an unknown user', async () => {
    await createLogin('staff1');
    const wrong = await login('staff1', 'nope-nope');
    const unknown = await login('ghost');
    expect(wrong.statusCode).toBe(401);
    expect(unknown.statusCode).toBe(401);
    expect(wrong.json()).toEqual(unknown.json());
  });

  it('refuses deactivated staff', async () => {
    const id = await createLogin('inactive1');
    await ctx.db.updateTable('staff').set({ is_active: false }).where('id', '=', id).execute();
    expect((await login('inactive1')).statusCode).toBe(401);
  });

  it('blocks repeated failures (brute force)', async () => {
    await createLogin('brute1');
    for (let i = 0; i < 5; i++) expect((await login('brute1', 'wrong-pass')).statusCode).toBe(401);
    const blocked = await login('brute1'); // even the right password is refused now
    expect(blocked.statusCode).toBe(429);
    expect(blocked.json().error.code).toBe('TOO_MANY_ATTEMPTS');
  });

  it('validates the body', async () => {
    const res = await ctx.app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { username: '' } });
    expect(res.statusCode).toBe(400);
  });
});

describe('POST /auth/refresh', () => {
  it('rotates the refresh token', async () => {
    await createLogin('rotate1');
    const first = (await login('rotate1')).json().data;
    const res = await refresh(first.refreshToken);
    expect(res.statusCode).toBe(200);
    const second = res.json().data;
    expect(second.refreshToken).not.toBe(first.refreshToken);
    // The old access token's session is now revoked.
    const me = await ctx.app.inject({
      method: 'GET',
      url: '/api/v1/auth/me',
      headers: { authorization: `Bearer ${first.accessToken}` },
    });
    expect(me.statusCode).toBe(401);
  });

  it('revokes the whole family when an old token is replayed', async () => {
    await createLogin('replay1');
    const first = (await login('replay1')).json().data;
    const second = (await refresh(first.refreshToken)).json().data;
    expect((await refresh(first.refreshToken)).statusCode).toBe(401); // replay
    expect((await refresh(second.refreshToken)).statusCode).toBe(401); // family killed
  });

  it('lets only one of two simultaneous refreshes win', async () => {
    await createLogin('race1');
    const { refreshToken } = (await login('race1')).json().data;
    const results = await Promise.all([refresh(refreshToken), refresh(refreshToken)]);
    const codes = results.map((r) => r.statusCode).sort();
    expect(codes).toEqual([200, 401]);
    const active = await ctx.db
      .selectFrom('auth_sessions as a')
      .innerJoin('staff as s', 's.id', 'a.staff_id')
      .select(sql<number>`count(*)::int`.as('n'))
      .where('s.username', '=', 'race1')
      .where('a.revoked_at', 'is', null)
      .executeTakeFirstOrThrow();
    expect(active.n).toBe(0); // the loser was a replay ⇒ whole family revoked
  });

  it('rejects unknown tokens', async () => {
    expect((await refresh('x'.repeat(43))).statusCode).toBe(401);
  });
});

describe('logout and me', () => {
  it('returns the current user and revokes the session on logout', async () => {
    await createLogin('logout1');
    const { accessToken, refreshToken } = (await login('logout1')).json().data;
    const headers = { authorization: `Bearer ${accessToken}` };

    const me = await ctx.app.inject({ method: 'GET', url: '/api/v1/auth/me', headers });
    expect(me.statusCode).toBe(200);
    expect(me.json().data.fullName).toBe('User logout1');

    expect((await ctx.app.inject({ method: 'POST', url: '/api/v1/auth/logout', headers })).statusCode).toBe(204);
    expect((await ctx.app.inject({ method: 'GET', url: '/api/v1/auth/me', headers })).statusCode).toBe(401);
    expect((await refresh(refreshToken)).statusCode).toBe(401);
  });
});

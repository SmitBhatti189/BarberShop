import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { sql } from 'kysely';
import { createDb, type Db } from '../../src/db/database.js';
import { syncPermissions } from '../../src/db/sync-permissions.js';
import { ALL_PERMISSION_KEYS, DEFAULT_STAFF_PERMISSIONS, SYSTEM_ROLES } from '../../src/shared/permissions.js';
import { resetDatabase, testDatabaseUrl } from '../helpers/test-context.js';

let db: Db;

beforeAll(async () => {
  db = createDb({ connectionString: testDatabaseUrl(), maxConnections: 2 });
  await resetDatabase(db);
});

afterAll(async () => {
  await db.destroy();
});

async function rolePermissionKeys(roleName: string): Promise<string[]> {
  const rows = await db
    .selectFrom('roles as r')
    .innerJoin('role_permissions as rp', 'rp.role_id', 'r.id')
    .innerJoin('permissions as p', 'p.id', 'rp.permission_id')
    .select('p.key')
    .where('r.name', '=', roleName)
    .orderBy('p.key')
    .execute();
  return rows.map((r) => r.key);
}

describe('foundation migration', () => {
  it('seeds the settings row and the main branch', async () => {
    const settings = await db.selectFrom('settings').selectAll().execute();
    expect(settings).toHaveLength(1);
    expect(settings[0]).toMatchObject({
      currency_code: 'INR',
      allow_negative_stock: false,
      appointment_buffer_minutes: 10,
      bill_round_off_unit: '10.00',
      payout_round_off_unit: '10.00',
    });
    const branches = await db.selectFrom('branches').select(['name', 'invoice_prefix', 'next_invoice_no']).execute();
    expect(branches).toEqual([{ name: 'Main Branch', invoice_prefix: 'MAIN', next_invoice_no: 1 }]);
  });

  it('allows only one settings row', async () => {
    await expect(db.insertInto('settings').values({ id: 1 }).execute()).rejects.toMatchObject({ code: '23505' });
  });

  it('syncs every permission key and gives the Manager all of them', async () => {
    const keys = (await db.selectFrom('permissions').select('key').execute()).map((r) => r.key).sort();
    expect(keys).toEqual([...ALL_PERMISSION_KEYS].sort());
    expect(await rolePermissionKeys(SYSTEM_ROLES.MANAGER)).toEqual([...ALL_PERMISSION_KEYS].sort());
    expect(await rolePermissionKeys(SYSTEM_ROLES.STAFF)).toEqual([...DEFAULT_STAFF_PERMISSIONS].sort());
  });

  it('keeps manager edits to the Staff role when syncing again', async () => {
    const staffRole = await db.selectFrom('roles').select('id').where('name', '=', SYSTEM_ROLES.STAFF).executeTakeFirstOrThrow();
    await db.deleteFrom('role_permissions').where('role_id', '=', staffRole.id).execute();
    await syncPermissions(db);
    expect(await rolePermissionKeys(SYSTEM_ROLES.STAFF)).toEqual([]);
  });

  it('requires username and password hash together', async () => {
    const role = await db.selectFrom('roles').select('id').executeTakeFirstOrThrow();
    const branch = await db.selectFrom('branches').select('id').executeTakeFirstOrThrow();
    await expect(
      db.insertInto('staff').values({ branch_id: branch.id, role_id: role.id, full_name: 'A', username: 'a' }).execute(),
    ).rejects.toMatchObject({ code: '23514' });
    // An employee without any login is valid.
    await db.insertInto('staff').values({ branch_id: branch.id, role_id: role.id, full_name: 'No Login' }).execute();
  });

  it('treats usernames case-insensitively', async () => {
    const role = await db.selectFrom('roles').select('id').executeTakeFirstOrThrow();
    const branch = await db.selectFrom('branches').select('id').executeTakeFirstOrThrow();
    const base = { branch_id: branch.id, role_id: role.id, full_name: 'X', password_hash: 'h' };
    await db.insertInto('staff').values({ ...base, username: 'Rahul' }).execute();
    await expect(db.insertInto('staff').values({ ...base, username: 'rahul' }).execute()).rejects.toMatchObject({
      code: '23505',
    });
  });

  it('maintains updated_at via trigger', async () => {
    const before = await db.selectFrom('branches').select('updated_at').executeTakeFirstOrThrow();
    await sql`SELECT pg_sleep(0.01)`.execute(db);
    await db.updateTable('branches').set({ phone: '9999999999' }).execute();
    const after = await db.selectFrom('branches').select('updated_at').executeTakeFirstOrThrow();
    expect(after.updated_at.getTime()).toBeGreaterThan(before.updated_at.getTime());
  });
});

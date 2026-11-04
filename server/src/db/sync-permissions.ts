import { sql, type Transaction } from 'kysely';
import type { Db } from './database.js';
import type { Database } from './types.js';
import {
  ALL_PERMISSION_KEYS,
  DEFAULT_STAFF_PERMISSIONS,
  PERMISSION_DESCRIPTIONS,
  SYSTEM_ROLES,
} from '../shared/permissions.js';

/**
 * Makes the database match `shared/permissions.ts`:
 *  - upserts every permission key (and description),
 *  - removes keys that no longer exist in code,
 *  - ensures the built-in Manager role exists and holds every permission,
 *  - creates the built-in Staff role with its defaults the first time only
 *    (later edits by the manager are preserved).
 * Idempotent; runs after every `db:migrate`.
 */
export async function syncPermissions(db: Db): Promise<void> {
  await db.transaction().execute(async (trx) => {
    await trx
      .insertInto('permissions')
      .values(ALL_PERMISSION_KEYS.map((key) => ({ key, description: PERMISSION_DESCRIPTIONS[key] })))
      .onConflict((oc) => oc.column('key').doUpdateSet({ description: (eb) => eb.ref('excluded.description') }))
      .execute();
    await trx.deleteFrom('permissions').where('key', 'not in', ALL_PERMISSION_KEYS).execute();

    const managerId = await ensureSystemRole(trx, SYSTEM_ROLES.MANAGER, 'Full access to every feature');
    await trx
      .insertInto('role_permissions')
      .columns(['role_id', 'permission_id'])
      .expression(trx.selectFrom('permissions').select([sql.lit(managerId).as('role_id'), 'id as permission_id']))
      .onConflict((oc) => oc.doNothing())
      .execute();

    const existingStaff = await trx
      .selectFrom('roles')
      .select('id')
      .where(sql`lower(name)`, '=', SYSTEM_ROLES.STAFF.toLowerCase())
      .executeTakeFirst();
    if (!existingStaff) {
      const staffId = await ensureSystemRole(trx, SYSTEM_ROLES.STAFF, 'Default role for salon staff');
      await trx
        .insertInto('role_permissions')
        .columns(['role_id', 'permission_id'])
        .expression(
          trx
            .selectFrom('permissions')
            .select([sql.lit(staffId).as('role_id'), 'id as permission_id'])
            .where('key', 'in', DEFAULT_STAFF_PERMISSIONS),
        )
        .execute();
    }
  });
}

async function ensureSystemRole(trx: Transaction<Database>, name: string, description: string): Promise<number> {
  const existing = await trx
    .selectFrom('roles')
    .select('id')
    .where(sql`lower(name)`, '=', name.toLowerCase())
    .executeTakeFirst();
  if (existing) return existing.id;
  const created = await trx
    .insertInto('roles')
    .values({ name, description, is_system: true })
    .returning('id')
    .executeTakeFirstOrThrow();
  return created.id;
}

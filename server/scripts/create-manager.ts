/**
 * Creates (or resets the password of) a Manager login, so a fresh install has
 * someone who can sign in and create everyone else from the app.
 *
 *   MANAGER_USERNAME=owner MANAGER_PASSWORD='…' MANAGER_NAME='Salon Owner' npm run staff:create-manager
 *
 * The values may also live in server/.env (never committed).
 */
import { sql } from 'kysely';
import { createDb } from '../src/db/database.js';
import { hashPassword } from '../src/modules/auth/password.js';
import { SYSTEM_ROLES } from '../src/shared/permissions.js';

const { DATABASE_URL, MANAGER_USERNAME, MANAGER_PASSWORD, MANAGER_NAME } = process.env;
if (!DATABASE_URL || !MANAGER_USERNAME || !MANAGER_PASSWORD) {
  throw new Error('DATABASE_URL, MANAGER_USERNAME and MANAGER_PASSWORD must be set');
}
if (MANAGER_PASSWORD.length < 8) throw new Error('MANAGER_PASSWORD must be at least 8 characters');

const db = createDb({ connectionString: DATABASE_URL, maxConnections: 1 });
try {
  const passwordHash = await hashPassword(MANAGER_PASSWORD);
  await db.transaction().execute(async (trx) => {
    const role = await trx
      .selectFrom('roles')
      .select('id')
      .where(sql`lower(name)`, '=', SYSTEM_ROLES.MANAGER.toLowerCase())
      .executeTakeFirstOrThrow(() => new Error('Manager role missing — run npm run db:migrate first'));
    const branch = await trx.selectFrom('branches').select('id').orderBy('id').executeTakeFirstOrThrow();

    const existing = await trx
      .selectFrom('staff')
      .select('id')
      .where(sql`lower(username)`, '=', MANAGER_USERNAME.toLowerCase())
      .executeTakeFirst();
    if (existing) {
      await trx
        .updateTable('staff')
        .set({ password_hash: passwordHash, role_id: role.id, is_active: true })
        .where('id', '=', existing.id)
        .execute();
      console.log(`Updated manager "${MANAGER_USERNAME}" (id ${existing.id}).`);
    } else {
      const created = await trx
        .insertInto('staff')
        .values({
          branch_id: branch.id,
          role_id: role.id,
          full_name: MANAGER_NAME ?? 'Salon Manager',
          username: MANAGER_USERNAME,
          password_hash: passwordHash,
          performs_services: false,
        })
        .returning('id')
        .executeTakeFirstOrThrow();
      console.log(`Created manager "${MANAGER_USERNAME}" (id ${created.id}).`);
    }
  });
} finally {
  await db.destroy();
}

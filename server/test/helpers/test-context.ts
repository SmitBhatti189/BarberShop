import { randomUUID } from 'node:crypto';
import { sql } from 'kysely';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../../src/app.js';
import { loadEnv } from '../../src/config/env.js';
import { createDb, type Db } from '../../src/db/database.js';
import { createMigrator, migrateToLatest } from '../../src/db/migrate.js';
import { SYSTEM_ROLES } from '../../src/shared/permissions.js';

/**
 * Database-backed test context. Uses TEST_DATABASE_URL (never the dev DB),
 * rebuilds the schema from scratch once per file, and offers helpers to
 * create staff and sign tokens.
 */
export interface TestContext {
  db: Db;
  app: FastifyInstance;
  createStaff(options?: { role?: string; active?: boolean }): Promise<{ staffId: number; sessionId: number; token: string }>;
  close(): Promise<void>;
}

export function testDatabaseUrl(): string {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is not set — see server/.env.example');
  return url;
}

export async function resetDatabase(db: Db): Promise<void> {
  // Roll back everything, then re-apply: proves down() and up() both work.
  const migrator = createMigrator(db);
  for (;;) {
    const { error, results } = await migrator.migrateDown();
    if (error) throw error;
    if (!results?.length) break;
  }
  const { error } = await migrateToLatest(db);
  if (error) throw error;
}

export async function createTestContext(
  register?: (app: FastifyInstance) => void | Promise<void>,
): Promise<TestContext> {
  const connectionString = testDatabaseUrl();
  const db = createDb({ connectionString, maxConnections: 5 });
  await resetDatabase(db);

  const env = loadEnv({ ...process.env, DATABASE_URL: connectionString, NODE_ENV: 'test' });
  const app = await buildApp({ env, db }, false);
  await register?.(app);
  await app.ready();

  return {
    db,
    app,
    async createStaff({ role = SYSTEM_ROLES.STAFF, active = true } = {}) {
      const roleRow = await db
        .selectFrom('roles')
        .select('id')
        .where(sql`lower(name)`, '=', role.toLowerCase())
        .executeTakeFirstOrThrow();
      const branch = await db.selectFrom('branches').select('id').executeTakeFirstOrThrow();
      const staff = await db
        .insertInto('staff')
        .values({ branch_id: branch.id, full_name: `Test ${role}`, role_id: roleRow.id, is_active: active })
        .returning('id')
        .executeTakeFirstOrThrow();
      const session = await db
        .insertInto('auth_sessions')
        .values({
          staff_id: staff.id,
          refresh_token_hash: randomUUID(),
          family_id: randomUUID(),
          expires_at: new Date(Date.now() + 86_400_000),
        })
        .returning('id')
        .executeTakeFirstOrThrow();
      const token = app.jwt.sign({ sub: String(staff.id), sid: session.id });
      return { staffId: staff.id, sessionId: session.id, token };
    },
    async close() {
      await app.close();
      await db.destroy();
    },
  };
}

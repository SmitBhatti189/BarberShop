/**
 * One-time local setup: creates the application login role and the dev + test
 * databases, then migrates both. Uses the `postgres` superuser only here; the
 * API itself always connects as the unprivileged application role.
 *
 *   npm run db:setup
 */
import pg from 'pg';
import { createDb } from '../src/db/database.js';
import { migrateToLatest } from '../src/db/migrate.js';

const superPassword = process.env.PG_SUPERUSER_PASSWORD;
const targets = [process.env.DATABASE_URL, process.env.TEST_DATABASE_URL].filter((u): u is string => Boolean(u));
if (!superPassword || targets.length === 0) {
  throw new Error('PG_SUPERUSER_PASSWORD and DATABASE_URL must be set (see .env.example)');
}

const first = new URL(targets[0]!);
const admin = new pg.Client({
  host: first.hostname,
  port: Number(first.port || 5432),
  user: 'postgres',
  password: superPassword,
  database: 'postgres',
});
await admin.connect();

try {
  for (const target of targets) {
    const url = new URL(target);
    const role = decodeURIComponent(url.username);
    const password = decodeURIComponent(url.password);
    const database = url.pathname.slice(1);

    const roleExists = await admin.query('SELECT 1 FROM pg_roles WHERE rolname = $1', [role]);
    const roleSql = roleExists.rowCount ? 'ALTER ROLE' : 'CREATE ROLE';
    await admin.query(
      `${roleSql} ${admin.escapeIdentifier(role)} LOGIN PASSWORD ${admin.escapeLiteral(password)} NOSUPERUSER NOCREATEROLE`,
    );

    const dbExists = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [database]);
    if (!dbExists.rowCount) {
      await admin.query(
        `CREATE DATABASE ${admin.escapeIdentifier(database)} OWNER ${admin.escapeIdentifier(role)} ENCODING 'UTF8'`,
      );
      console.log(`Created database ${database}`);
    } else {
      console.log(`Database ${database} already exists`);
    }

    const db = createDb({ connectionString: target, maxConnections: 1 });
    try {
      const result = await migrateToLatest(db);
      if (result.error) throw result.error;
      console.log(`Migrated ${database} (${result.results?.length ?? 0} applied)`);
    } finally {
      await db.destroy();
    }
  }
} finally {
  await admin.end();
}

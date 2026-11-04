import { Migrator, type MigrationResultSet } from 'kysely/migration';
import { pathToFileURL } from 'node:url';
import { createDb, type Db } from './database.js';
import { migrations } from './migrations/index.js';
import { syncPermissions } from './sync-permissions.js';

export function createMigrator(db: Db): Migrator {
  return new Migrator({
    db,
    provider: { getMigrations: async () => migrations },
  });
}

/** Applies all pending migrations, then syncs permission keys from code. */
export async function migrateToLatest(db: Db): Promise<MigrationResultSet> {
  const result = await createMigrator(db).migrateToLatest();
  if (!result.error) await syncPermissions(db);
  return result;
}

function report({ error, results }: MigrationResultSet): void {
  for (const r of results ?? []) {
    const marker = r.status === 'Success' ? 'ok ' : r.status === 'Error' ? 'ERR' : 'skip';
    console.log(`[${marker}] ${r.direction.toLowerCase()} ${r.migrationName}`);
  }
  if (!results?.length && !error) console.log('Database is already up to date.');
  if (error) {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  }
}

// CLI: `tsx src/db/migrate.ts latest|down`
if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const command = process.argv[2] ?? 'latest';
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is not set');
  const db = createDb({ connectionString: url, maxConnections: 1 });
  try {
    if (command === 'latest') report(await migrateToLatest(db));
    else if (command === 'down') report(await createMigrator(db).migrateDown());
    else throw new Error(`Unknown command "${command}" (use latest | down)`);
  } finally {
    await db.destroy();
  }
}

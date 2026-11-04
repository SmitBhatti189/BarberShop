import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';
import type { Database } from './types.js';

// BIGINT (int8) ids and counts: our ids stay far below 2^53, so parse to number.
pg.types.setTypeParser(pg.types.builtins.INT8, (value) => Number(value));
// NUMERIC stays a string (exact); DATE stays a 'YYYY-MM-DD' string so it is
// never shifted by the server's timezone.
pg.types.setTypeParser(pg.types.builtins.DATE, (value) => value);

export type Db = Kysely<Database>;

export interface DbOptions {
  connectionString: string;
  maxConnections?: number;
}

export function createDb({ connectionString, maxConnections = 10 }: DbOptions): Db {
  const pool = new pg.Pool({
    connectionString,
    max: maxConnections,
    idleTimeoutMillis: 30_000,
    // Generous: on a busy salon PC (just booted, antivirus scanning) a new
    // PostgreSQL connection on Windows can take several seconds.
    connectionTimeoutMillis: 15_000,
    // Every session works in UTC; branch-local days are computed explicitly.
    options: '-c timezone=UTC',
  });
  return new Kysely<Database>({ dialect: new PostgresDialect({ pool }) });
}

import type { Kysely, Transaction } from 'kysely';
import type { Database } from './types.js';
import type { Db } from './database.js';

/** Repositories accept either the root db or an open transaction. */
export type Executor = Kysely<Database> | Transaction<Database>;

// PostgreSQL error codes that are safe to retry by re-running the whole transaction.
const RETRYABLE_CODES = new Set(['40001' /* serialization_failure */, '40P01' /* deadlock_detected */]);

export interface TransactionOptions {
  isolation?: 'read committed' | 'repeatable read' | 'serializable';
  /** Extra attempts after a serialization failure or deadlock. */
  retries?: number;
}

/**
 * Runs `work` in a single transaction. Any thrown error rolls everything back.
 * Serialization failures and deadlocks are retried with a short jittered
 * back-off, so callers can rely on "all or nothing" under concurrency.
 */
export async function withTransaction<T>(
  db: Db,
  work: (trx: Transaction<Database>) => Promise<T>,
  { isolation = 'read committed', retries = 3 }: TransactionOptions = {},
): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await db.transaction().setIsolationLevel(isolation).execute(work);
    } catch (error) {
      if (attempt >= retries || !isRetryable(error)) throw error;
      await new Promise((resolve) => setTimeout(resolve, 10 * 2 ** attempt + Math.random() * 10));
    }
  }
}

function isRetryable(error: unknown): boolean {
  return typeof error === 'object' && error !== null && RETRYABLE_CODES.has((error as { code?: string }).code ?? '');
}

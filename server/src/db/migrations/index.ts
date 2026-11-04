import type { Migration } from 'kysely/migration';
import * as m0001 from './0001_foundation.js';

/**
 * Ordered registry of migrations. Add each new migration here; names must sort
 * in execution order and must never be renamed once applied anywhere.
 * (An explicit registry avoids dynamic file imports, which are fragile on Windows.)
 */
export const migrations: Record<string, Migration> = {
  '0001_foundation': m0001,
};

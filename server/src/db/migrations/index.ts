import type { Migration } from 'kysely/migration';
import * as m0001 from './0001_foundation.js';
import * as m0002 from './0002_inventory.js';
import * as m0003 from './0003_services.js';
import * as m0004 from './0004_compensation.js';

/**
 * Ordered registry of migrations. Add each new migration here; names must sort
 * in execution order and must never be renamed once applied anywhere.
 * (An explicit registry avoids dynamic file imports, which are fragile on Windows.)
 */
export const migrations: Record<string, Migration> = {
  '0001_foundation': m0001,
  '0002_inventory': m0002,
  '0003_services': m0003,
  '0004_compensation': m0004,
};

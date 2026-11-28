import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';

export interface RoleDto {
  id: number;
  name: string;
  description: string | null;
  isSystem: boolean;
}

/** System roles first, then the rest alphabetically. */
export function listRoles(db: Executor): Promise<RoleDto[]> {
  return db
    .selectFrom('roles')
    .select(['id', 'name', 'description', 'is_system as isSystem'])
    .orderBy('is_system', 'desc')
    .orderBy(sql`lower(name)`)
    .execute();
}

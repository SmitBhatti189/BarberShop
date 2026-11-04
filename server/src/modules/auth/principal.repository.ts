import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';
import type { PermissionKey } from '../../shared/permissions.js';

/** The authenticated caller, resolved fresh from the database on every request. */
export interface Principal {
  staffId: number;
  sessionId: number;
  branchId: number;
  fullName: string;
  roleId: number;
  permissions: ReadonlySet<PermissionKey>;
}

/**
 * Loads the caller in ONE query, and only if the session is still valid and
 * the staff member is still active. Doing this per request means deactivating
 * a staff member, revoking a session or changing a role takes effect
 * immediately — not when the access token expires.
 */
export async function findActivePrincipal(
  db: Executor,
  staffId: number,
  sessionId: number,
): Promise<Principal | null> {
  const row = await db
    .selectFrom('auth_sessions as a')
    .innerJoin('staff as s', 's.id', 'a.staff_id')
    .leftJoin('role_permissions as rp', 'rp.role_id', 's.role_id')
    .leftJoin('permissions as p', 'p.id', 'rp.permission_id')
    .select([
      's.id as staffId',
      's.branch_id as branchId',
      's.full_name as fullName',
      's.role_id as roleId',
      sql<string[]>`coalesce(array_agg(p.key) FILTER (WHERE p.key IS NOT NULL), '{}')`.as('permissions'),
    ])
    .where('a.id', '=', sessionId)
    .where('a.staff_id', '=', staffId)
    .where('a.revoked_at', 'is', null)
    .where('a.expires_at', '>', sql<Date>`now()`)
    .where('s.is_active', '=', true)
    .groupBy(['s.id'])
    .executeTakeFirst();

  if (!row) return null;
  return {
    staffId: row.staffId,
    sessionId,
    branchId: row.branchId,
    fullName: row.fullName,
    roleId: row.roleId,
    permissions: new Set(row.permissions as PermissionKey[]),
  };
}

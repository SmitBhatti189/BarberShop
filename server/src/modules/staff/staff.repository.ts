import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';
import type { StaffUpdate } from '../../db/types.js';
import { SYSTEM_ROLES } from '../../shared/permissions.js';
import type { ListStaffQuery, StaffDto } from './staff.schemas.js';

/** Columns returned to clients — never the password hash. */
function selectStaff(db: Executor) {
  return db
    .selectFrom('staff as s')
    .innerJoin('roles as r', 'r.id', 's.role_id')
    .select([
      's.id',
      's.full_name as fullName',
      's.mobile',
      's.email',
      's.role_id as roleId',
      'r.name as roleName',
      's.is_active as isActive',
      's.performs_services as performsServices',
      's.joined_on as joinedOn',
      's.username',
      's.version',
      's.created_at as createdAt',
    ]);
}

type StaffRow = Omit<StaffDto, 'createdAt'> & { createdAt: Date };

function toDto(row: StaffRow): StaffDto {
  return { ...row, createdAt: row.createdAt.toISOString() };
}

export async function listStaff(db: Executor, q: ListStaffQuery): Promise<{ rows: StaffDto[]; total: number }> {
  let query = selectStaff(db);
  if (q.status !== 'all') query = query.where('s.is_active', '=', q.status === 'active');
  if (q.search) {
    const term = `%${q.search.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const digits = q.search.replace(/\D/g, '');
    query = query.where((eb) =>
      eb.or([
        eb('s.full_name', 'ilike', term),
        eb('s.username', 'ilike', term),
        ...(digits.length >= 3 ? [eb('s.mobile', 'like', `%${digits}%`)] : []),
      ]),
    );
  }
  const [rows, count] = await Promise.all([
    query.orderBy('s.is_active', 'desc').orderBy(sql`lower(s.full_name)`).orderBy('s.id').limit(q.limit).offset(q.offset).execute(),
    query.clearSelect().select(sql<number>`count(*)::int`.as('n')).executeTakeFirstOrThrow(),
  ]);
  return { rows: rows.map(toDto), total: count.n };
}

export async function findStaff(db: Executor, id: number): Promise<StaffDto | null> {
  const row = await selectStaff(db).where('s.id', '=', id).executeTakeFirst();
  return row ? toDto(row) : null;
}

export async function roleExists(db: Executor, roleId: number): Promise<boolean> {
  return Boolean(await db.selectFrom('roles').select('id').where('id', '=', roleId).executeTakeFirst());
}

export async function defaultBranchId(db: Executor): Promise<number> {
  const row = await db.selectFrom('branches').select('id').where('is_active', '=', true).orderBy('id').executeTakeFirstOrThrow();
  return row.id;
}

export async function insertStaff(
  db: Executor,
  values: {
    branchId: number;
    fullName: string;
    mobile: string | null;
    email: string | null;
    roleId: number;
    performsServices: boolean;
    joinedOn: string | null;
    username: string | null;
    passwordHash: string | null;
  },
): Promise<number> {
  const row = await db
    .insertInto('staff')
    .values({
      branch_id: values.branchId,
      full_name: values.fullName,
      mobile: values.mobile,
      email: values.email,
      role_id: values.roleId,
      performs_services: values.performsServices,
      joined_on: values.joinedOn,
      username: values.username,
      password_hash: values.passwordHash,
    })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

/**
 * Applies [changes] only if the row is still at [expectedVersion], bumping
 * the version. Returns false when someone else saved first.
 */
export async function updateStaffIfVersion(
  db: Executor,
  id: number,
  expectedVersion: number,
  changes: StaffUpdate,
): Promise<boolean> {
  const result = await db
    .updateTable('staff')
    .set({ ...changes, version: sql`version + 1` })
    .where('id', '=', id)
    .where('version', '=', expectedVersion)
    .executeTakeFirst();
  return result.numUpdatedRows > 0n;
}

export async function setStaffFields(db: Executor, id: number, changes: StaffUpdate): Promise<void> {
  await db
    .updateTable('staff')
    .set({ ...changes, version: sql`version + 1` })
    .where('id', '=', id)
    .execute();
}

/** Signs [staffId] out everywhere, optionally keeping one session (the caller's own). */
export async function revokeAllSessions(db: Executor, staffId: number, keepSessionId?: number): Promise<void> {
  let query = db
    .updateTable('auth_sessions')
    .set({ revoked_at: sql`now()` })
    .where('staff_id', '=', staffId)
    .where('revoked_at', 'is', null);
  if (keepSessionId !== undefined) query = query.where('id', '!=', keepSessionId);
  await query.execute();
}

/**
 * Active managers who can sign in, locked for the rest of the transaction.
 * Locking them serialises any change that could remove the last one, so two
 * simultaneous changes can never leave the salon without a manager.
 */
export async function lockActiveSignInManagers(db: Executor): Promise<number[]> {
  const rows = await db
    .selectFrom('staff as s')
    .innerJoin('roles as r', 'r.id', 's.role_id')
    .select('s.id')
    .where(sql`lower(r.name)`, '=', SYSTEM_ROLES.MANAGER.toLowerCase())
    .where('r.is_system', '=', true)
    .where('s.is_active', '=', true)
    .where('s.username', 'is not', null)
    .orderBy('s.id')
    .forUpdate('s')
    .execute();
  return rows.map((r) => r.id);
}

export async function managerRoleId(db: Executor): Promise<number> {
  const row = await db
    .selectFrom('roles')
    .select('id')
    .where(sql`lower(name)`, '=', SYSTEM_ROLES.MANAGER.toLowerCase())
    .where('is_system', '=', true)
    .executeTakeFirstOrThrow();
  return row.id;
}

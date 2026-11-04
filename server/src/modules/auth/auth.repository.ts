import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';

export interface LoginCandidate {
  id: number;
  passwordHash: string;
  isActive: boolean;
}

export async function findLoginCandidate(db: Executor, username: string): Promise<LoginCandidate | null> {
  const row = await db
    .selectFrom('staff')
    .select(['id', 'password_hash as passwordHash', 'is_active as isActive'])
    .where(sql`lower(username)`, '=', username.toLowerCase())
    .where('password_hash', 'is not', null)
    .executeTakeFirst();
  return row ? { id: row.id, passwordHash: row.passwordHash!, isActive: row.isActive } : null;
}

export async function updatePasswordHash(db: Executor, staffId: number, passwordHash: string): Promise<void> {
  await db.updateTable('staff').set({ password_hash: passwordHash }).where('id', '=', staffId).execute();
}

export interface NewSession {
  staffId: number;
  tokenHash: string;
  familyId: string;
  expiresAt: Date;
  deviceLabel: string | null;
}

export async function insertSession(db: Executor, s: NewSession): Promise<number> {
  const row = await db
    .insertInto('auth_sessions')
    .values({
      staff_id: s.staffId,
      refresh_token_hash: s.tokenHash,
      family_id: s.familyId,
      expires_at: s.expiresAt,
      device_label: s.deviceLabel,
    })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

export interface SessionForRefresh {
  id: number;
  staffId: number;
  familyId: string;
  expiresAt: Date;
  revokedAt: Date | null;
  deviceLabel: string | null;
  staffActive: boolean;
}

/** Locks the session row so two refreshes of the same token cannot both succeed. */
export async function findSessionForRefreshForUpdate(db: Executor, tokenHash: string): Promise<SessionForRefresh | null> {
  const row = await db
    .selectFrom('auth_sessions as a')
    .innerJoin('staff as s', 's.id', 'a.staff_id')
    .select([
      'a.id',
      'a.staff_id as staffId',
      'a.family_id as familyId',
      'a.expires_at as expiresAt',
      'a.revoked_at as revokedAt',
      'a.device_label as deviceLabel',
      's.is_active as staffActive',
    ])
    .where('a.refresh_token_hash', '=', tokenHash)
    .forUpdate('a')
    .executeTakeFirst();
  return row ?? null;
}

export async function revokeSession(db: Executor, sessionId: number): Promise<void> {
  await db
    .updateTable('auth_sessions')
    .set({ revoked_at: sql`now()` })
    .where('id', '=', sessionId)
    .where('revoked_at', 'is', null)
    .execute();
}

export async function revokeFamily(db: Executor, familyId: string): Promise<void> {
  await db
    .updateTable('auth_sessions')
    .set({ revoked_at: sql`now()` })
    .where('family_id', '=', familyId)
    .where('revoked_at', 'is', null)
    .execute();
}

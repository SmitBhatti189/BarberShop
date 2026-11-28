import type { Db } from '../../db/database.js';
import { withTransaction, type Executor } from '../../db/transaction.js';
import { BusinessRuleError, ConflictError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { hashPassword } from '../auth/password.js';
import type { Principal } from '../auth/principal.repository.js';
import * as repo from './staff.repository.js';
import type { CreateStaffInput, ListStaffQuery, LoginInput, StaffDto, UpdateStaffInput } from './staff.schemas.js';

// Unique constraints on `staff` → which form field the clash belongs to.
const UNIQUE_FIELDS: Record<string, { field: string; message: string }> = {
  staff_mobile_key: { field: 'mobile', message: 'Another employee already has this mobile number' },
  staff_username_uq: { field: 'username', message: 'This username is already taken' },
  staff_email_uq: { field: 'email', message: 'Another employee already has this email address' },
};

/**
 * Employee management. Rules enforced here (never only in the app):
 *  - you cannot deactivate yourself or remove your own login;
 *  - the salon always keeps at least one active Manager who can sign in;
 *  - edits use the record's version, so two people editing at once cannot
 *    silently overwrite each other;
 *  - deactivating, removing a login or changing a password signs that person
 *    out everywhere.
 */
export class StaffService {
  constructor(private readonly db: Db) {}

  list(query: ListStaffQuery) {
    return repo.listStaff(this.db, query);
  }

  async get(id: number): Promise<StaffDto> {
    const staff = await repo.findStaff(this.db, id);
    if (!staff) throw new NotFoundError('Employee');
    return staff;
  }

  async create(input: CreateStaffInput): Promise<StaffDto> {
    if (!(await repo.roleExists(this.db, input.roleId))) {
      throw new ValidationError('Request validation failed', [{ field: 'roleId', message: 'Choose a role' }]);
    }
    const passwordHash = input.login ? await hashPassword(input.login.password) : null;
    const id = await withUniqueFields(async () =>
      repo.insertStaff(this.db, {
        branchId: await repo.defaultBranchId(this.db),
        fullName: input.fullName,
        mobile: input.mobile ?? null,
        email: input.email ?? null,
        roleId: input.roleId,
        performsServices: input.performsServices,
        joinedOn: input.joinedOn ?? null,
        username: input.login?.username ?? null,
        passwordHash,
      }),
    );
    return this.get(id);
  }

  async update(id: number, input: UpdateStaffInput): Promise<StaffDto> {
    if (input.roleId !== undefined && !(await repo.roleExists(this.db, input.roleId))) {
      throw new ValidationError('Request validation failed', [{ field: 'roleId', message: 'Choose a role' }]);
    }
    await withUniqueFields(() =>
      withTransaction(this.db, async (trx) => {
        if (input.roleId !== undefined) {
          const managerRole = await repo.managerRoleId(trx);
          await ensureManagerRemains(trx, id, input.roleId === managerRole);
        }
        const saved = await repo.updateStaffIfVersion(trx, id, input.version, {
          ...(input.fullName !== undefined && { full_name: input.fullName }),
          ...(input.mobile !== undefined && { mobile: input.mobile }),
          ...(input.email !== undefined && { email: input.email }),
          ...(input.roleId !== undefined && { role_id: input.roleId }),
          ...(input.performsServices !== undefined && { performs_services: input.performsServices }),
          ...(input.joinedOn !== undefined && { joined_on: input.joinedOn }),
        });
        if (!saved) await this.throwStaleOrMissing(trx, id);
      }),
    );
    return this.get(id);
  }

  async setActive(id: number, active: boolean, actor: Principal): Promise<StaffDto> {
    if (!active && id === actor.staffId) {
      throw new BusinessRuleError('CANNOT_DEACTIVATE_SELF', 'You cannot deactivate your own account');
    }
    await withTransaction(this.db, async (trx) => {
      await this.mustExist(trx, id);
      if (!active) {
        await ensureManagerRemains(trx, id, false);
        await repo.revokeAllSessions(trx, id);
      }
      await repo.setStaffFields(trx, id, { is_active: active });
    });
    return this.get(id);
  }

  /** Creates the login, or changes its username and password. */
  async setLogin(id: number, input: LoginInput, actor: Principal): Promise<StaffDto> {
    const passwordHash = await hashPassword(input.password);
    await withUniqueFields(() =>
      withTransaction(this.db, async (trx) => {
        await this.mustExist(trx, id);
        await repo.setStaffFields(trx, id, { username: input.username, password_hash: passwordHash });
        // A new password ends every other session; changing your own keeps you signed in here.
        await repo.revokeAllSessions(trx, id, id === actor.staffId ? actor.sessionId : undefined);
      }),
    );
    return this.get(id);
  }

  async removeLogin(id: number, actor: Principal): Promise<StaffDto> {
    if (id === actor.staffId) {
      throw new BusinessRuleError('CANNOT_REMOVE_OWN_LOGIN', 'You cannot remove your own login');
    }
    await withTransaction(this.db, async (trx) => {
      await this.mustExist(trx, id);
      await ensureManagerRemains(trx, id, false);
      await repo.setStaffFields(trx, id, { username: null, password_hash: null });
      await repo.revokeAllSessions(trx, id);
    });
    return this.get(id);
  }

  private async mustExist(db: Executor, id: number): Promise<void> {
    if (!(await repo.findStaff(db, id))) throw new NotFoundError('Employee');
  }

  private async throwStaleOrMissing(db: Executor, id: number): Promise<never> {
    await this.mustExist(db, id);
    throw new ConflictError('STALE', 'Someone else changed this employee. Reload and try again.');
  }
}

/**
 * Throws if [staffId] is currently an active sign-in Manager, will not be one
 * after this change ([stillManagerAfter] = false), and is the last one.
 */
async function ensureManagerRemains(db: Executor, staffId: number, stillManagerAfter: boolean): Promise<void> {
  const managers = await repo.lockActiveSignInManagers(db);
  if (!stillManagerAfter && managers.includes(staffId) && managers.length === 1) {
    throw new BusinessRuleError(
      'LAST_MANAGER',
      'This is the only active manager who can sign in. Give another employee the Manager role first.',
    );
  }
}

/** Turns a unique-constraint clash into a 409 that names the form field. */
async function withUniqueFields<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    const e = error as { code?: string; constraint?: string };
    const clash = e.code === '23505' && e.constraint ? UNIQUE_FIELDS[e.constraint] : undefined;
    if (clash) throw new ConflictError('DUPLICATE', clash.message, [clash]);
    throw error;
  }
}

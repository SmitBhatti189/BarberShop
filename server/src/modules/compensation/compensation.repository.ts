import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';
import type { CommissionItemType } from '../../db/types.js';

export async function salonDefaultPct(db: Executor): Promise<string> {
  const row = await db.selectFrom('settings').select('default_commission_pct').executeTakeFirstOrThrow();
  return row.default_commission_pct;
}

export async function setSalonDefaultPct(db: Executor, pct: string): Promise<void> {
  await db.updateTable('settings').set({ default_commission_pct: pct }).execute();
}

/** Active employees with their current salary and how many own rates they have. */
export function listPaySummaries(db: Executor) {
  return db
    .selectFrom('staff as s')
    .innerJoin('roles as r', 'r.id', 's.role_id')
    .leftJoin('staff_compensation as c', (j) => j.onRef('c.staff_id', '=', 's.id').on('c.effective_to', 'is', null))
    .select([
      's.id as staffId',
      's.full_name as fullName',
      'r.name as roleName',
      's.performs_services as performsServices',
      'c.monthly_salary as monthlySalary',
      sql<number>`(
        SELECT count(*)::int FROM commission_rules cr
        WHERE cr.staff_id = s.id AND cr.effective_to IS NULL
      )`.as('specificRates'),
    ])
    .where('s.is_active', '=', true)
    .orderBy(sql`lower(s.full_name)`)
    .execute();
}

export async function findStaffBasics(db: Executor, staffId: number) {
  return db
    .selectFrom('staff as s')
    .innerJoin('roles as r', 'r.id', 's.role_id')
    .select(['s.id', 's.full_name as fullName', 'r.name as roleName', 's.performs_services as performsServices', 's.is_active as isActive'])
    .where('s.id', '=', staffId)
    .executeTakeFirst();
}

/** Locks the employee row so two saves of the same employee's pay run one after another. */
export async function lockStaff(db: Executor, staffId: number): Promise<void> {
  await db.selectFrom('staff').select('id').where('id', '=', staffId).forUpdate().executeTakeFirstOrThrow();
}

/** The database clock right now (after any lock was granted), for history boundaries. */
export async function clockNow(db: Executor): Promise<Date> {
  const row = await sql<{ now: Date }>`SELECT clock_timestamp() AS now`.execute(db);
  return row.rows[0]!.now;
}

export async function currentSalary(db: Executor, staffId: number) {
  return db
    .selectFrom('staff_compensation')
    .select(['id', 'monthly_salary as monthlySalary'])
    .where('staff_id', '=', staffId)
    .where('effective_to', 'is', null)
    .executeTakeFirst();
}

export async function closeSalary(db: Executor, id: number, at: Date): Promise<void> {
  await db.updateTable('staff_compensation').set({ effective_to: at }).where('id', '=', id).execute();
}

export async function insertSalary(db: Executor, staffId: number, salary: string, at: Date, by: number): Promise<void> {
  await db
    .insertInto('staff_compensation')
    .values({ staff_id: staffId, monthly_salary: salary, effective_from: at, created_by: by })
    .execute();
}

export interface CurrentRule {
  id: number;
  itemType: CommissionItemType;
  itemId: number;
  ratePct: string;
}

export async function currentRules(db: Executor, staffId: number): Promise<CurrentRule[]> {
  return db
    .selectFrom('commission_rules')
    .select([
      'id',
      'item_type as itemType',
      sql<number>`coalesce(service_id, product_id)`.as('itemId'),
      'rate_pct as ratePct',
    ])
    .where('staff_id', '=', staffId)
    .where('effective_to', 'is', null)
    .execute();
}

export async function closeRule(db: Executor, id: number, at: Date): Promise<void> {
  await db.updateTable('commission_rules').set({ effective_to: at }).where('id', '=', id).execute();
}

export async function insertRule(
  db: Executor,
  r: { staffId: number; itemType: CommissionItemType; itemId: number; ratePct: string; at: Date; by: number },
): Promise<void> {
  await db
    .insertInto('commission_rules')
    .values({
      staff_id: r.staffId,
      item_type: r.itemType,
      service_id: r.itemType === 'SERVICE' ? r.itemId : null,
      product_id: r.itemType === 'PRODUCT' ? r.itemId : null,
      rate_pct: r.ratePct,
      effective_from: r.at,
      created_by: r.by,
    })
    .execute();
}

export function activeServices(db: Executor) {
  return db
    .selectFrom('services')
    .select(['id', 'name', 'category', 'price'])
    .where('is_active', '=', true)
    .orderBy(sql`lower(coalesce(category, 'zzz'))`)
    .orderBy(sql`lower(name)`)
    .execute();
}

export function activeProducts(db: Executor) {
  return db
    .selectFrom('products')
    .select(['id', 'name', 'brand', 'category', 'mrp', 'default_discount_pct as discountPct'])
    .where('is_active', '=', true)
    .orderBy(sql`lower(coalesce(category, 'zzz'))`)
    .orderBy(sql`lower(name)`)
    .execute();
}

/** Ids among [ids] that exist and are active for [type]. */
export async function activeItemIds(db: Executor, type: CommissionItemType, ids: number[]): Promise<Set<number>> {
  if (ids.length === 0) return new Set();
  const table = type === 'SERVICE' ? 'services' : 'products';
  const rows = await db.selectFrom(table).select('id').where('id', 'in', ids).where('is_active', '=', true).execute();
  return new Set(rows.map((r) => r.id));
}

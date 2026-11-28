import { sql } from 'kysely';
import type { Executor } from '../../db/transaction.js';
import type { ListServicesQuery, ServiceDto } from './services.schemas.js';

function selectServices(db: Executor) {
  return db
    .selectFrom('services')
    .select([
      'id',
      'name',
      'category',
      'description',
      'price',
      'duration_minutes as durationMinutes',
      'is_active as isActive',
      'version',
    ]);
}

export async function listServices(db: Executor, q: ListServicesQuery): Promise<{ rows: ServiceDto[]; total: number }> {
  let query = selectServices(db);
  if (q.status !== 'all') query = query.where('is_active', '=', q.status === 'active');
  if (q.category) query = query.where(sql`lower(category)`, '=', q.category.toLowerCase());
  if (q.search) {
    const term = `%${q.search.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    query = query.where((eb) => eb.or([eb('name', 'ilike', term), eb('category', 'ilike', term)]));
  }
  const [rows, count] = await Promise.all([
    query
      .orderBy('is_active', 'desc')
      .orderBy(sql`lower(coalesce(category, 'zzz'))`)
      .orderBy(sql`lower(name)`)
      .orderBy('id')
      .limit(q.limit)
      .offset(q.offset)
      .execute(),
    query.clearSelect().select(sql<number>`count(*)::int`.as('n')).executeTakeFirstOrThrow(),
  ]);
  return { rows, total: count.n };
}

export async function findService(db: Executor, id: number): Promise<ServiceDto | null> {
  return (await selectServices(db).where('id', '=', id).executeTakeFirst()) ?? null;
}

/** Categories in use, one per case-insensitive name, spelled as first entered. */
export async function categories(db: Executor): Promise<string[]> {
  const rows = await db
    .selectFrom('services')
    .select(sql<string>`(array_agg(category ORDER BY id))[1]`.as('v'))
    .where('category', 'is not', null)
    .where('is_active', '=', true)
    .groupBy(sql`lower(category)`)
    .orderBy(sql`lower(category)`)
    .execute();
  return rows.map((r) => r.v);
}

export async function insertService(
  db: Executor,
  v: { name: string; category: string | null; description: string | null; price: string; durationMinutes: number },
): Promise<number> {
  const row = await db
    .insertInto('services')
    .values({
      name: v.name,
      category: v.category,
      description: v.description,
      price: v.price,
      duration_minutes: v.durationMinutes,
    })
    .returning('id')
    .executeTakeFirstOrThrow();
  return row.id;
}

export async function updateServiceIfVersion(
  db: Executor,
  id: number,
  expectedVersion: number,
  changes: Partial<{
    name: string;
    category: string | null;
    description: string | null;
    price: string;
    duration_minutes: number;
  }>,
): Promise<boolean> {
  const result = await db
    .updateTable('services')
    .set({ ...changes, version: sql`version + 1` })
    .where('id', '=', id)
    .where('version', '=', expectedVersion)
    .executeTakeFirst();
  return result.numUpdatedRows > 0n;
}

export async function setServiceActive(db: Executor, id: number, active: boolean): Promise<void> {
  await db
    .updateTable('services')
    .set({ is_active: active, version: sql`version + 1` })
    .where('id', '=', id)
    .execute();
}

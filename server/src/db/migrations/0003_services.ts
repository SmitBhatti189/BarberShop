import { sql, type Kysely } from 'kysely';

/**
 * 0003 — Services and prices. A combo ("Haircut + Beard") is its own row with
 * its own price. Bills will copy the name and price at the time of sale, so
 * changing a price here never alters history. See docs/DATABASE_DESIGN.md §4.4.
 */
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('services')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('name', 'text', (c) => c.notNull().check(sql`length(trim(name)) > 0`))
    .addColumn('category', 'text')
    .addColumn('description', 'text')
    .addColumn('price', sql`numeric(12,2)`, (c) => c.notNull().check(sql`price >= 0`))
    .addColumn('duration_minutes', 'integer', (c) => c.notNull().check(sql`duration_minutes BETWEEN 1 AND 600`))
    .addColumn('is_active', 'boolean', (c) => c.notNull().defaultTo(true))
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .execute();
  // The same service name can't be listed twice while active.
  await sql`CREATE UNIQUE INDEX services_name_active_uq ON services (lower(name)) WHERE is_active`.execute(db);
  await sql`CREATE INDEX services_category_idx ON services (lower(category)) WHERE category IS NOT NULL`.execute(db);
  await sql`
    CREATE TRIGGER services_set_updated_at
    BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()
  `.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('services').ifExists().execute();
}

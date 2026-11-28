import { sql, type Kysely } from 'kysely';

/**
 * 0004 — Pay setup: salon-wide default commission, monthly salaries and
 * per-employee commission rates for services and products.
 *
 * Owner rule (2026-11-24): an employee's rate for an item is their specific
 * rate if set; otherwise the salon default — but only for employees with no
 * monthly salary. Salaried employees earn commission only where a specific
 * rate is set. Both tables keep history (effective_from / effective_to);
 * bills will copy the rate in force, so later changes never alter earnings.
 */
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .alterTable('settings')
    .addColumn('default_commission_pct', sql`numeric(5,2)`, (c) =>
      c.notNull().defaultTo('0.00').check(sql`default_commission_pct BETWEEN 0 AND 100`),
    )
    .execute();

  await db.schema
    .createTable('staff_compensation')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('staff_id', 'bigint', (c) => c.notNull().references('staff.id').onDelete('restrict'))
    .addColumn('monthly_salary', sql`numeric(12,2)`, (c) => c.notNull().check(sql`monthly_salary > 0`))
    .addColumn('effective_from', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('effective_to', 'timestamptz')
    .addColumn('created_by', 'bigint', (c) => c.notNull().references('staff.id').onDelete('restrict'))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addCheckConstraint('staff_compensation_period_ck', sql`effective_to IS NULL OR effective_to > effective_from`)
    .execute();
  // One salary at a time per employee.
  await sql`
    ALTER TABLE staff_compensation ADD CONSTRAINT staff_compensation_no_overlap
    EXCLUDE USING gist (staff_id WITH =, tstzrange(effective_from, effective_to, '[)') WITH &&)
  `.execute(db);
  await sql`CREATE UNIQUE INDEX staff_compensation_current_uq ON staff_compensation (staff_id) WHERE effective_to IS NULL`.execute(db);

  await db.schema
    .createTable('commission_rules')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('staff_id', 'bigint', (c) => c.notNull().references('staff.id').onDelete('restrict'))
    .addColumn('item_type', 'text', (c) => c.notNull().check(sql`item_type IN ('SERVICE', 'PRODUCT')`))
    .addColumn('service_id', 'bigint', (c) => c.references('services.id').onDelete('restrict'))
    .addColumn('product_id', 'bigint', (c) => c.references('products.id').onDelete('restrict'))
    .addColumn('rate_pct', sql`numeric(5,2)`, (c) => c.notNull().check(sql`rate_pct BETWEEN 0 AND 100`))
    .addColumn('effective_from', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('effective_to', 'timestamptz')
    .addColumn('created_by', 'bigint', (c) => c.notNull().references('staff.id').onDelete('restrict'))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addCheckConstraint(
      'commission_rules_item_ck',
      sql`(item_type = 'SERVICE' AND service_id IS NOT NULL AND product_id IS NULL)
       OR (item_type = 'PRODUCT' AND product_id IS NOT NULL AND service_id IS NULL)`,
    )
    .addCheckConstraint('commission_rules_period_ck', sql`effective_to IS NULL OR effective_to > effective_from`)
    .execute();
  // One rate in force per employee per item.
  await sql`
    CREATE UNIQUE INDEX commission_rules_current_uq
    ON commission_rules (staff_id, item_type, coalesce(service_id, product_id))
    WHERE effective_to IS NULL
  `.execute(db);
  await sql`CREATE INDEX commission_rules_staff_idx ON commission_rules (staff_id) WHERE effective_to IS NULL`.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('commission_rules').ifExists().execute();
  await db.schema.dropTable('staff_compensation').ifExists().execute();
  await db.schema.alterTable('settings').dropColumn('default_commission_pct').execute();
}

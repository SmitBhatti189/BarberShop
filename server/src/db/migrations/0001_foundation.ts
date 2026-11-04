import { sql, type Kysely } from 'kysely';

/**
 * 0001 — Foundation: organisation, configuration and access control.
 * Tables: branches, settings, permissions, roles, role_permissions, staff, auth_sessions.
 * Business tables (customers, catalogue, billing …) arrive with their modules.
 * See docs/DATABASE_DESIGN.md §4.1–4.2.
 */
export async function up(db: Kysely<any>): Promise<void> {
  await sql`CREATE EXTENSION IF NOT EXISTS btree_gist`.execute(db);
  await sql`CREATE EXTENSION IF NOT EXISTS pg_trgm`.execute(db);

  // Shared trigger: keeps updated_at current on every UPDATE.
  await sql`
    CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
    BEGIN
      NEW.updated_at := now();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
  `.execute(db);

  await db.schema
    .createTable('branches')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('name', 'text', (c) => c.notNull())
    .addColumn('address', 'text')
    .addColumn('phone', 'text')
    .addColumn('timezone', 'text', (c) => c.notNull().defaultTo('Asia/Kolkata'))
    .addColumn('invoice_prefix', 'text', (c) => c.notNull().unique().check(sql`invoice_prefix ~ '^[A-Z0-9]{1,10}$'`))
    .addColumn('next_invoice_no', 'bigint', (c) => c.notNull().defaultTo(1).check(sql`next_invoice_no >= 1`))
    .addColumn('is_active', 'boolean', (c) => c.notNull().defaultTo(true))
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .execute();

  await db.schema
    .createTable('settings')
    .addColumn('id', 'smallint', (c) => c.primaryKey().defaultTo(1).check(sql`id = 1`))
    .addColumn('currency_code', 'text', (c) => c.notNull().defaultTo('INR'))
    .addColumn('allow_negative_stock', 'boolean', (c) => c.notNull().defaultTo(false))
    .addColumn('appointment_buffer_minutes', 'integer', (c) =>
      c.notNull().defaultTo(10).check(sql`appointment_buffer_minutes BETWEEN 0 AND 60`),
    )
    .addColumn('bill_round_off_unit', sql`numeric(12,2)`, (c) =>
      c.notNull().defaultTo('10.00').check(sql`bill_round_off_unit IN (0, 1, 5, 10)`),
    )
    .addColumn('payout_round_off_unit', sql`numeric(12,2)`, (c) =>
      c.notNull().defaultTo('10.00').check(sql`payout_round_off_unit IN (0, 1, 5, 10)`),
    )
    .addColumn('tax_enabled', 'boolean', (c) => c.notNull().defaultTo(false))
    .addColumn('tax_rate_pct', sql`numeric(5,2)`, (c) =>
      c.notNull().defaultTo('0.00').check(sql`tax_rate_pct BETWEEN 0 AND 100`),
    )
    .addColumn('prices_include_tax', 'boolean', (c) => c.notNull().defaultTo(false))
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .execute();

  await db.schema
    .createTable('permissions')
    .addColumn('id', 'smallint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('key', 'text', (c) => c.notNull().unique())
    .addColumn('description', 'text', (c) => c.notNull())
    .execute();

  await db.schema
    .createTable('roles')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('name', 'text', (c) => c.notNull())
    .addColumn('description', 'text')
    .addColumn('is_system', 'boolean', (c) => c.notNull().defaultTo(false))
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .execute();
  await sql`CREATE UNIQUE INDEX roles_name_uq ON roles (lower(name))`.execute(db);

  await db.schema
    .createTable('role_permissions')
    .addColumn('role_id', 'bigint', (c) => c.notNull().references('roles.id').onDelete('cascade'))
    .addColumn('permission_id', 'smallint', (c) => c.notNull().references('permissions.id').onDelete('cascade'))
    .addPrimaryKeyConstraint('role_permissions_pk', ['role_id', 'permission_id'])
    .execute();

  await db.schema
    .createTable('staff')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('branch_id', 'bigint', (c) => c.notNull().references('branches.id').onDelete('restrict'))
    .addColumn('full_name', 'text', (c) => c.notNull().check(sql`length(trim(full_name)) > 0`))
    .addColumn('mobile', 'text', (c) => c.unique())
    .addColumn('email', 'text')
    .addColumn('username', 'text')
    .addColumn('password_hash', 'text')
    .addColumn('role_id', 'bigint', (c) => c.notNull().references('roles.id').onDelete('restrict'))
    .addColumn('is_active', 'boolean', (c) => c.notNull().defaultTo(true))
    .addColumn('performs_services', 'boolean', (c) => c.notNull().defaultTo(true))
    .addColumn('joined_on', 'date')
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    // Login is optional, but username and password come as a pair.
    .addCheckConstraint('staff_login_pair_ck', sql`(username IS NULL) = (password_hash IS NULL)`)
    .execute();
  await sql`CREATE UNIQUE INDEX staff_username_uq ON staff (lower(username)) WHERE username IS NOT NULL`.execute(db);
  await sql`CREATE UNIQUE INDEX staff_email_uq ON staff (lower(email)) WHERE email IS NOT NULL`.execute(db);
  await db.schema.createIndex('staff_branch_idx').on('staff').column('branch_id').execute();
  await db.schema.createIndex('staff_role_idx').on('staff').column('role_id').execute();

  await db.schema
    .createTable('auth_sessions')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('staff_id', 'bigint', (c) => c.notNull().references('staff.id').onDelete('cascade'))
    .addColumn('refresh_token_hash', 'text', (c) => c.notNull().unique())
    .addColumn('family_id', 'uuid', (c) => c.notNull())
    .addColumn('expires_at', 'timestamptz', (c) => c.notNull())
    .addColumn('revoked_at', 'timestamptz')
    .addColumn('device_label', 'text')
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .execute();
  await sql`CREATE INDEX auth_sessions_active_idx ON auth_sessions (staff_id) WHERE revoked_at IS NULL`.execute(db);
  await db.schema.createIndex('auth_sessions_family_idx').on('auth_sessions').column('family_id').execute();

  for (const table of ['branches', 'settings', 'roles', 'staff']) {
    await sql`
      CREATE TRIGGER ${sql.raw(`${table}_set_updated_at`)}
      BEFORE UPDATE ON ${sql.table(table)}
      FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    `.execute(db);
  }

  // Seed rows every installation needs. Permission keys and system roles are
  // synced from code after migrations run (see db/sync-permissions.ts).
  await db.insertInto('settings').values({ id: 1 }).execute();
  await db.insertInto('branches').values({ name: 'Main Branch', invoice_prefix: 'MAIN' }).execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  for (const table of ['auth_sessions', 'staff', 'role_permissions', 'roles', 'permissions', 'settings', 'branches']) {
    await db.schema.dropTable(table).ifExists().execute();
  }
  await sql`DROP FUNCTION IF EXISTS set_updated_at()`.execute(db);
}

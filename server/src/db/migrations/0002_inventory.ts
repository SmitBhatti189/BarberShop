import { sql, type Kysely } from 'kysely';

/**
 * 0002 — Inventory: products, per-branch stock, and the stock-movement ledger.
 * Pricing (owner decision 2026-11-24): a product has an MRP and a default
 * discount %; its selling price is MRP less that discount (computed, not
 * stored). Each delivery's buying price lives on its PURCHASE movement only.
 * See docs/DATABASE_DESIGN.md §4.4.
 */
export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('products')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('name', 'text', (c) => c.notNull().check(sql`length(trim(name)) > 0`))
    .addColumn('brand', 'text')
    .addColumn('category', 'text')
    .addColumn('mrp', sql`numeric(12,2)`, (c) => c.notNull().check(sql`mrp > 0`))
    .addColumn('default_discount_pct', sql`numeric(5,2)`, (c) =>
      c.notNull().defaultTo('0.00').check(sql`default_discount_pct BETWEEN 0 AND 100`),
    )
    .addColumn('is_active', 'boolean', (c) => c.notNull().defaultTo(true))
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .execute();
  // The same product (name + brand) can't be listed twice while active.
  await sql`
    CREATE UNIQUE INDEX products_name_brand_active_uq
    ON products (lower(name), lower(coalesce(brand, ''))) WHERE is_active
  `.execute(db);
  await sql`CREATE INDEX products_name_trgm_idx ON products USING gin (name gin_trgm_ops)`.execute(db);
  await sql`CREATE INDEX products_category_idx ON products (lower(category)) WHERE category IS NOT NULL`.execute(db);

  await db.schema
    .createTable('product_stock')
    .addColumn('branch_id', 'bigint', (c) => c.notNull().references('branches.id').onDelete('restrict'))
    .addColumn('product_id', 'bigint', (c) => c.notNull().references('products.id').onDelete('restrict'))
    // No CHECK (quantity >= 0): negative stock is a setting, enforced under row lock in the service.
    .addColumn('quantity', 'integer', (c) => c.notNull().defaultTo(0))
    .addColumn('low_stock_threshold', 'integer', (c) => c.notNull().defaultTo(0).check(sql`low_stock_threshold >= 0`))
    .addColumn('version', 'integer', (c) => c.notNull().defaultTo(1))
    .addColumn('updated_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    .addPrimaryKeyConstraint('product_stock_pk', ['branch_id', 'product_id'])
    .execute();
  await sql`
    CREATE INDEX product_stock_low_idx ON product_stock (branch_id)
    WHERE quantity <= low_stock_threshold
  `.execute(db);

  await db.schema
    .createTable('stock_movements')
    .addColumn('id', 'bigint', (c) => c.primaryKey().generatedAlwaysAsIdentity())
    .addColumn('branch_id', 'bigint', (c) => c.notNull().references('branches.id').onDelete('restrict'))
    .addColumn('product_id', 'bigint', (c) => c.notNull().references('products.id').onDelete('restrict'))
    .addColumn('movement_type', 'text', (c) =>
      c.notNull().check(sql`movement_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT', 'SALE_REVERSAL')`),
    )
    .addColumn('quantity_delta', 'integer', (c) => c.notNull().check(sql`quantity_delta <> 0`))
    .addColumn('unit_cost', sql`numeric(12,2)`, (c) => c.check(sql`unit_cost >= 0`))
    .addColumn('supplier_name', 'text')
    .addColumn('supplier_invoice_no', 'text')
    .addColumn('reason', 'text')
    .addColumn('note', 'text')
    .addColumn('created_by', 'bigint', (c) => c.notNull().references('staff.id').onDelete('restrict'))
    .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
    // A purchase brings stock in at a known buying price.
    .addCheckConstraint(
      'stock_movements_purchase_ck',
      sql`movement_type <> 'PURCHASE' OR (quantity_delta > 0 AND unit_cost IS NOT NULL)`,
    )
    // A manual adjustment always says why.
    .addCheckConstraint('stock_movements_adjustment_ck', sql`movement_type <> 'ADJUSTMENT' OR reason IS NOT NULL`)
    .execute();
  // bill_item_id (for SALE / SALE_REVERSAL) is added by the billing migration.
  await sql`CREATE INDEX stock_movements_product_idx ON stock_movements (branch_id, product_id, id DESC)`.execute(db);
  await sql`
    CREATE INDEX stock_movements_last_purchase_idx ON stock_movements (product_id, id DESC)
    WHERE movement_type = 'PURCHASE'
  `.execute(db);

  for (const table of ['products', 'product_stock']) {
    await sql`
      CREATE TRIGGER ${sql.raw(`${table}_set_updated_at`)}
      BEFORE UPDATE ON ${sql.table(table)}
      FOR EACH ROW EXECUTE FUNCTION set_updated_at()
    `.execute(db);
  }
}

export async function down(db: Kysely<any>): Promise<void> {
  for (const table of ['stock_movements', 'product_stock', 'products']) {
    await db.schema.dropTable(table).ifExists().execute();
  }
}

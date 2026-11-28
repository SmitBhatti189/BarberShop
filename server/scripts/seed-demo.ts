/**
 * Demo data for trying the app: salon products with opening stock, services,
 * employees, and their pay (salon default commission, salaries, own rates). Goes through the same service classes as the API, so every
 * business rule applies (prices, stock ledger, duplicate checks).
 * Safe to run again: anything that already exists is skipped.
 *
 *   npm run db:seed:demo
 *
 * Pay is set only for employees with no pay history yet, so changes made in
 * the app are never overwritten.
 * NOT for production data.
 */
import { sql } from 'kysely';
import { createDb } from '../src/db/database.js';
import type { Principal } from '../src/modules/auth/principal.repository.js';
import { CompensationService } from '../src/modules/compensation/compensation.service.js';
import { InventoryService } from '../src/modules/inventory/inventory.service.js';
import { ServicesService } from '../src/modules/services/services.service.js';
import { StaffService } from '../src/modules/staff/staff.service.js';
import { SYSTEM_ROLES } from '../src/shared/permissions.js';

const url = process.env.DATABASE_URL;
if (!url) throw new Error('DATABASE_URL is not set');
const db = createDb({ connectionString: url, maxConnections: 2 });

/** name, brand, category, MRP, default discount %, low-stock alert, opening qty, buying price, supplier */
const PRODUCTS: [string, string, string, number, number, number, number, number, string][] = [
  ['Anti-dandruff Shampoo 340 ml', 'Head & Shoulders', 'Shampoo', 420, 5, 4, 15, 330, 'Sharma Traders'],
  ['Argan Oil Shampoo 250 ml', 'Moroccanoil', 'Shampoo', 1350, 10, 2, 6, 980, 'Sharma Traders'],
  ['Repair Conditioner 180 ml', "L'Oréal Professionnel", 'Conditioner', 650, 10, 3, 10, 480, 'Glow Distributors'],
  ['Coconut Hair Oil 300 ml', 'Parachute', 'Hair oil', 210, 0, 5, 24, 160, 'Local Wholesale'],
  ['Onion Hair Oil 200 ml', 'Mamaearth', 'Hair oil', 449, 10, 4, 3, 320, 'Glow Distributors'],
  ['Hair Gel Extra Hold 250 ml', 'Set Wet', 'Gel', 199, 0, 5, 20, 135, 'Local Wholesale'],
  ['Matte Hair Wax 75 g', 'Beardo', 'Wax', 399, 10, 3, 8, 260, 'Beardo Direct'],
  ['Hair Clay Strong Hold 50 g', 'Gatsby', 'Wax', 350, 5, 3, 2, 230, 'Beardo Direct'],
  ['Beard Oil 30 ml', 'Beardo', 'Beard care', 449, 15, 3, 12, 290, 'Beardo Direct'],
  ['Beard Wash 100 ml', 'Ustraa', 'Beard care', 299, 10, 3, 0, 0, 'Beardo Direct'],
  ['Aftershave Lotion 100 ml', 'Old Spice', 'Shaving', 275, 0, 4, 9, 200, 'Local Wholesale'],
  ['Shaving Cream 70 g', 'Gillette', 'Shaving', 120, 0, 6, 30, 85, 'Local Wholesale'],
];

/** full name, mobile, role, performs services, joined on, optional [username, password] */
const STAFF: [string, string, 'Manager' | 'Staff', boolean, string, [string, string] | null][] = [
  ['Rahul Verma', '9876501001', 'Staff', true, '2025-04-01', ['rahul.v', 'demo-staff-123']],
  ['Asha Rao', '9876501002', 'Staff', true, '2025-06-15', ['asha', 'demo-staff-123']],
  ['Imran Khan', '9876501003', 'Staff', true, '2025-09-10', null],
  ['Vikram Singh', '9876501004', 'Staff', true, '2026-01-05', null],
  ['Neha Joshi', '9876501005', 'Staff', false, '2026-03-20', ['neha', 'demo-staff-123']],
  ['Deepak Patel', '9876501006', 'Manager', true, '2024-11-01', ['deepak', 'demo-manager-123']],
];

/** name, category, price, minutes */
const SERVICES: [string, string, number, number][] = [
  ['Haircut', 'Hair', 200, 30],
  ['Beard Trim', 'Beard', 100, 15],
  ['Haircut + Beard', 'Combo', 280, 45],
  ['Kids Haircut', 'Hair', 150, 20],
  ['Clean Shave', 'Beard', 120, 20],
  ['Hair Colour', 'Colour', 800, 60],
  ['Hair Spa', 'Treatment', 600, 45],
  ['Head Massage', 'Treatment', 250, 20],
  ['Face Cleanup', 'Skin', 400, 30],
];

/** Salon default commission % (commission-based staff, items without an own rate). Set only while it is 0. */
const SALON_DEFAULT_PCT = '10.00';

/** employee, monthly salary (null = commission-based), own rates [S = service / P = product, item name, %] */
const PAY: [string, number | null, ['S' | 'P', string, number][]][] = [
  [
    'Rahul Verma',
    null,
    [
      ['S', 'Haircut', 40],
      ['S', 'Haircut + Beard', 40],
      ['S', 'Hair Colour', 30],
      ['P', 'Matte Hair Wax 75 g', 15],
    ],
  ],
  [
    'Asha Rao',
    null,
    [
      ['S', 'Hair Spa', 35],
      ['S', 'Face Cleanup', 35],
      ['S', 'Hair Colour', 30],
    ],
  ],
  ['Imran Khan', null, []], // salon default on everything — nothing to store
  [
    'Vikram Singh',
    15000,
    [
      ['P', 'Beard Oil 30 ml', 5],
      ['P', 'Hair Gel Extra Hold 250 ml', 5],
    ],
  ],
  [
    'Neha Joshi',
    12000,
    [
      ['P', 'Argan Oil Shampoo 250 ml', 3],
      ['P', 'Repair Conditioner 180 ml', 3],
    ],
  ],
  ['Deepak Patel', 25000, []],
];

async function main() {
  // Act as the first active manager, as if they entered the data in the app.
  const owner = await db
    .selectFrom('staff as s')
    .innerJoin('roles as r', 'r.id', 's.role_id')
    .select(['s.id', 's.branch_id'])
    .where('r.name', '=', SYSTEM_ROLES.MANAGER)
    .where('s.is_active', '=', true)
    .orderBy('s.id')
    .executeTakeFirstOrThrow(() => new Error('No active manager — run npm run staff:create-manager first'));
  const actor: Principal = {
    staffId: owner.id,
    sessionId: 0,
    branchId: owner.branch_id,
    fullName: 'Demo seed',
    roleId: 0,
    permissions: new Set(),
  };

  const inventory = new InventoryService(db);
  let productsAdded = 0;
  for (const [name, brand, category, mrp, discount, alert, qty, cost, supplier] of PRODUCTS) {
    const exists = await db
      .selectFrom('products')
      .select('id')
      .where(sql`lower(name)`, '=', name.toLowerCase())
      .where(sql`lower(coalesce(brand, ''))`, '=', brand.toLowerCase())
      .executeTakeFirst();
    if (exists) continue;
    await inventory.create(actor, {
      name,
      brand,
      category,
      mrp: mrp.toFixed(2),
      defaultDiscountPct: discount.toFixed(2),
      lowStockThreshold: alert,
      ...(qty > 0 && {
        openingStock: { quantity: qty, unitCost: cost.toFixed(2), supplierName: supplier, invoiceNo: null, note: null },
      }),
    });
    productsAdded++;
  }

  const roles = await db.selectFrom('roles').select(['id', 'name']).execute();
  const roleId = (name: string) => roles.find((r) => r.name === name)!.id;
  const staffService = new StaffService(db);
  let staffAdded = 0;
  for (const [fullName, mobile, role, performsServices, joinedOn, login] of STAFF) {
    const exists = await db
      .selectFrom('staff')
      .select('id')
      .where((eb) => eb.or([eb('mobile', '=', mobile), eb(sql`lower(full_name)`, '=', fullName.toLowerCase())]))
      .executeTakeFirst();
    if (exists) continue;
    await staffService.create({
      fullName,
      mobile,
      email: null,
      roleId: roleId(role),
      performsServices,
      joinedOn,
      ...(login && { login: { username: login[0], password: login[1] } }),
    });
    staffAdded++;
  }

  const services = new ServicesService(db);
  let servicesAdded = 0;
  for (const [name, category, price, minutes] of SERVICES) {
    const exists = await db
      .selectFrom('services')
      .select('id')
      .where(sql`lower(name)`, '=', name.toLowerCase())
      .executeTakeFirst();
    if (exists) continue;
    await services.create({ name, category, description: null, price: price.toFixed(2), durationMinutes: minutes });
    servicesAdded++;
  }

  const pay = new CompensationService(db);
  if (Number((await pay.salonDefault()).defaultCommissionPct) === 0) await pay.setSalonDefault(SALON_DEFAULT_PCT);
  let paySet = 0;
  for (const [fullName, salary, rates] of PAY) {
    const staff = await db
      .selectFrom('staff')
      .select('id')
      .where(sql`lower(full_name)`, '=', fullName.toLowerCase())
      .executeTakeFirst();
    if (!staff) continue;
    const [salaryRow, ruleRow] = await Promise.all([
      db.selectFrom('staff_compensation').select('id').where('staff_id', '=', staff.id).executeTakeFirst(),
      db.selectFrom('commission_rules').select('id').where('staff_id', '=', staff.id).executeTakeFirst(),
    ]);
    if (salaryRow || ruleRow) continue; // already has pay history — leave it alone
    const resolved: { itemType: 'SERVICE' | 'PRODUCT'; itemId: number; ratePct: string }[] = [];
    for (const [kind, itemName, pct] of rates) {
      const item = await db
        .selectFrom(kind === 'S' ? 'services' : 'products')
        .select('id')
        .where('name', '=', itemName)
        .where('is_active', '=', true)
        .executeTakeFirst();
      if (item) resolved.push({ itemType: kind === 'S' ? 'SERVICE' : 'PRODUCT', itemId: item.id, ratePct: pct.toFixed(2) });
    }
    if (salary === null && resolved.length === 0) continue;
    await pay.savePay(actor, staff.id, { monthlySalary: salary === null ? null : salary.toFixed(2), rates: resolved });
    paySet++;
  }

  console.log(
    `Products added: ${productsAdded} (of ${PRODUCTS.length}); services added: ${servicesAdded} (of ${SERVICES.length}); ` +
      `employees added: ${staffAdded} (of ${STAFF.length}); pay set for ${paySet} employees; ` +
      `salon default ${(await pay.salonDefault()).defaultCommissionPct}%.`,
  );
}

try {
  await main();
} finally {
  await db.destroy();
}

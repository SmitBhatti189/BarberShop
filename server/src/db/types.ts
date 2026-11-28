import type { ColumnType, Generated, Insertable, Selectable, Updateable } from 'kysely';

/**
 * Kysely table types. Kept in sync with `migrations/` by hand: every migration
 * that changes a table updates its interface here in the same change.
 *
 * NUMERIC columns are typed as `string` because `pg` returns them as strings
 * (no float precision loss); convert with `shared/money.ts`.
 */

type Timestamp = ColumnType<Date, Date | string | undefined, Date | string>;
type CreatedAt = ColumnType<Date, never, never>;
type UpdatedAt = ColumnType<Date, never, Date | string>;

export interface BranchesTable {
  id: Generated<number>;
  name: string;
  address: string | null;
  phone: string | null;
  timezone: string;
  invoice_prefix: string;
  next_invoice_no: ColumnType<string, string | number | undefined, string | number>;
  is_active: Generated<boolean>;
  version: Generated<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface SettingsTable {
  id: ColumnType<number, 1 | undefined, never>;
  currency_code: Generated<string>;
  allow_negative_stock: Generated<boolean>;
  appointment_buffer_minutes: Generated<number>;
  bill_round_off_unit: ColumnType<string, string | undefined, string>;
  payout_round_off_unit: ColumnType<string, string | undefined, string>;
  tax_enabled: Generated<boolean>;
  tax_rate_pct: ColumnType<string, string | undefined, string>;
  prices_include_tax: Generated<boolean>;
  default_commission_pct: ColumnType<string, string | undefined, string>;
  version: Generated<number>;
  updated_at: UpdatedAt;
}

export interface PermissionsTable {
  id: Generated<number>;
  key: string;
  description: string;
}

export interface RolesTable {
  id: Generated<number>;
  name: string;
  description: string | null;
  is_system: Generated<boolean>;
  version: Generated<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface RolePermissionsTable {
  role_id: number;
  permission_id: number;
}

export interface StaffTable {
  id: Generated<number>;
  branch_id: number;
  full_name: string;
  mobile: string | null;
  email: string | null;
  username: string | null;
  password_hash: string | null;
  role_id: number;
  is_active: Generated<boolean>;
  performs_services: Generated<boolean>;
  /** 'YYYY-MM-DD' (DATE is returned as a string, see database.ts). */
  joined_on: string | null;
  version: Generated<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface AuthSessionsTable {
  id: Generated<number>;
  staff_id: number;
  refresh_token_hash: string;
  family_id: string;
  expires_at: Timestamp;
  revoked_at: Timestamp | null;
  device_label: string | null;
  created_at: CreatedAt;
}

export interface ProductsTable {
  id: Generated<number>;
  name: string;
  brand: string | null;
  category: string | null;
  /** NUMERIC as string. */
  mrp: string;
  default_discount_pct: ColumnType<string, string | undefined, string>;
  is_active: Generated<boolean>;
  version: Generated<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface ProductStockTable {
  branch_id: number;
  product_id: number;
  quantity: Generated<number>;
  low_stock_threshold: Generated<number>;
  version: Generated<number>;
  updated_at: UpdatedAt;
}

export type StockMovementType = 'PURCHASE' | 'SALE' | 'ADJUSTMENT' | 'SALE_REVERSAL';

export interface StockMovementsTable {
  id: Generated<number>;
  branch_id: number;
  product_id: number;
  movement_type: StockMovementType;
  quantity_delta: number;
  unit_cost: string | null;
  supplier_name: string | null;
  supplier_invoice_no: string | null;
  reason: string | null;
  note: string | null;
  created_by: number;
  created_at: CreatedAt;
}

export interface ServicesTable {
  id: Generated<number>;
  name: string;
  category: string | null;
  description: string | null;
  /** NUMERIC as string. */
  price: string;
  duration_minutes: number;
  is_active: Generated<boolean>;
  version: Generated<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface StaffCompensationTable {
  id: Generated<number>;
  staff_id: number;
  monthly_salary: string;
  effective_from: ColumnType<Date, Date | string | undefined, Date | string>;
  effective_to: ColumnType<Date | null, Date | string | null | undefined, Date | string | null>;
  created_by: number;
  created_at: CreatedAt;
}

export type CommissionItemType = 'SERVICE' | 'PRODUCT';

export interface CommissionRulesTable {
  id: Generated<number>;
  staff_id: number;
  item_type: CommissionItemType;
  service_id: number | null;
  product_id: number | null;
  rate_pct: string;
  effective_from: ColumnType<Date, Date | string | undefined, Date | string>;
  effective_to: ColumnType<Date | null, Date | string | null | undefined, Date | string | null>;
  created_by: number;
  created_at: CreatedAt;
}

export interface Database {
  branches: BranchesTable;
  settings: SettingsTable;
  permissions: PermissionsTable;
  roles: RolesTable;
  role_permissions: RolePermissionsTable;
  staff: StaffTable;
  auth_sessions: AuthSessionsTable;
  products: ProductsTable;
  product_stock: ProductStockTable;
  stock_movements: StockMovementsTable;
  services: ServicesTable;
  staff_compensation: StaffCompensationTable;
  commission_rules: CommissionRulesTable;
}

export type Staff = Selectable<StaffTable>;
export type NewStaff = Insertable<StaffTable>;
export type StaffUpdate = Updateable<StaffTable>;
export type Branch = Selectable<BranchesTable>;
export type Settings = Selectable<SettingsTable>;

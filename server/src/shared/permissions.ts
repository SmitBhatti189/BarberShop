/**
 * The ONLY place permission keys are defined. `npm run db:migrate` syncs this
 * list into the `permissions` table and grants every key to the built-in
 * Manager role. Routes reference these constants; the Flutter app receives the
 * caller's keys from `GET /auth/me` and never defines its own.
 */
export const PERMISSIONS = {
  STAFF_VIEW: 'staff.view',
  STAFF_MANAGE: 'staff.manage',
  ROLES_MANAGE: 'roles.manage',

  CUSTOMERS_VIEW: 'customers.view',
  CUSTOMERS_MANAGE: 'customers.manage',
  CUSTOMERS_HISTORY_VIEW: 'customers.history.view',

  SERVICES_VIEW: 'services.view',
  SERVICES_MANAGE: 'services.manage',

  INVENTORY_VIEW: 'inventory.view',
  INVENTORY_MANAGE: 'inventory.manage',

  APPOINTMENTS_VIEW: 'appointments.view',
  APPOINTMENTS_VIEW_ALL: 'appointments.view_all',
  APPOINTMENTS_MANAGE: 'appointments.manage',

  BILLING_CREATE: 'billing.create',
  BILLING_VIEW: 'billing.view',
  BILLING_DISCOUNT: 'billing.discount',
  BILLING_VOID: 'billing.void',

  PAYMENTS_RECORD: 'payments.record',
  PAYMENTS_VIEW: 'payments.view',

  COMPENSATION_VIEW: 'compensation.view',
  COMPENSATION_MANAGE: 'compensation.manage',
  EARNINGS_VIEW_OWN: 'earnings.view_own',
  WITHDRAWALS_REQUEST_OWN: 'withdrawals.request_own',
  WITHDRAWALS_CONFIRM: 'withdrawals.confirm',

  REPORTS_FINANCIAL_VIEW: 'reports.financial.view',
  SETTINGS_MANAGE: 'settings.manage',
} as const;

export type PermissionKey = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

export const PERMISSION_DESCRIPTIONS: Record<PermissionKey, string> = {
  'staff.view': 'View staff list and profiles',
  'staff.manage': 'Create, edit, activate and deactivate staff',
  'roles.manage': 'Create roles and assign permissions',
  'customers.view': 'View and search customers',
  'customers.manage': 'Create and edit customers',
  'customers.history.view': 'View customer visit and purchase history',
  'services.view': 'View services and prices',
  'services.manage': 'Create, edit and deactivate services and prices',
  'inventory.view': 'View products and stock levels',
  'inventory.manage': 'Manage products, stock purchases and adjustments',
  'appointments.view': 'View own appointments',
  'appointments.view_all': 'View appointments of all staff',
  'appointments.manage': 'Create, modify and cancel appointments',
  'billing.create': 'Create bills',
  'billing.view': 'View bills',
  'billing.discount': 'Give discounts and extra discounts on bills',
  'billing.void': 'Void finalised bills',
  'payments.record': 'Record payments against bills',
  'payments.view': 'View payment records and cash-collection reports',
  'compensation.view': 'View any staff compensation, earnings and ledger',
  'compensation.manage': 'Configure salaries and commission rules; post salary and settle',
  'earnings.view_own': 'View own work, commission and balance',
  'withdrawals.request_own': 'Enter own withdrawals and confirm entries made by the manager',
  'withdrawals.confirm': 'Enter and confirm withdrawals, advances and repayments for any staff',
  'reports.financial.view': 'View salon-wide sales and financial summaries',
  'settings.manage': 'Manage salon settings, branches and payment methods',
};

export const ALL_PERMISSION_KEYS = Object.values(PERMISSIONS) as PermissionKey[];

export const SYSTEM_ROLES = {
  MANAGER: 'Manager',
  STAFF: 'Staff',
} as const;

/**
 * Starting permissions for the built-in Staff role. Managers can change the
 * role (or create new ones) at any time; this only seeds a fresh database.
 */
export const DEFAULT_STAFF_PERMISSIONS: PermissionKey[] = [
  PERMISSIONS.CUSTOMERS_VIEW,
  PERMISSIONS.CUSTOMERS_MANAGE,
  PERMISSIONS.SERVICES_VIEW,
  PERMISSIONS.APPOINTMENTS_VIEW,
  PERMISSIONS.APPOINTMENTS_MANAGE,
  PERMISSIONS.BILLING_CREATE,
  PERMISSIONS.PAYMENTS_RECORD,
  PERMISSIONS.EARNINGS_VIEW_OWN,
  PERMISSIONS.WITHDRAWALS_REQUEST_OWN,
];

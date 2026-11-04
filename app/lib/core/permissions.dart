/// Permission keys, mirrored from `server/src/shared/permissions.ts` so the UI
/// can hide what the user cannot use. The backend is the authority: these are
/// UI hints only and must be kept identical to the server's list.
abstract final class Permissions {
  static const staffView = 'staff.view';
  static const staffManage = 'staff.manage';
  static const rolesManage = 'roles.manage';
  static const customersView = 'customers.view';
  static const customersManage = 'customers.manage';
  static const customersHistoryView = 'customers.history.view';
  static const servicesView = 'services.view';
  static const servicesManage = 'services.manage';
  static const inventoryView = 'inventory.view';
  static const inventoryManage = 'inventory.manage';
  static const appointmentsView = 'appointments.view';
  static const appointmentsViewAll = 'appointments.view_all';
  static const appointmentsManage = 'appointments.manage';
  static const billingCreate = 'billing.create';
  static const billingView = 'billing.view';
  static const billingDiscount = 'billing.discount';
  static const billingVoid = 'billing.void';
  static const paymentsRecord = 'payments.record';
  static const paymentsView = 'payments.view';
  static const compensationView = 'compensation.view';
  static const compensationManage = 'compensation.manage';
  static const earningsViewOwn = 'earnings.view_own';
  static const withdrawalsRequestOwn = 'withdrawals.request_own';
  static const withdrawalsConfirm = 'withdrawals.confirm';
  static const reportsFinancialView = 'reports.financial.view';
  static const settingsManage = 'settings.manage';
}

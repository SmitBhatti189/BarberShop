/// Paths inside the Staff & pay section.
abstract final class StaffRoutes {
  static const list = '/staff';
  static const newEmployee = '/staff/new';

  /// Commission & salary setup.
  static const pay = '/staff/pay';
  static String employee(int id) => '/staff/$id';
}

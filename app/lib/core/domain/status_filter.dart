/// Active / Inactive / All filter used by every list (employees, products,
/// services). [name] is what the API's `status` parameter expects.
enum StatusFilter {
  active('Active'),
  inactive('Inactive'),
  all('All');

  const StatusFilter(this.label);
  final String label;
}

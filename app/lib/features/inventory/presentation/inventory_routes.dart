/// Paths inside the Inventory section.
abstract final class InventoryRoutes {
  static const list = '/inventory';
  static const newProduct = '/inventory/new';
  static String product(int id) => '/inventory/$id';
}

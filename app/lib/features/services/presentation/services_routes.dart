/// Paths inside the Services section.
abstract final class ServicesRoutes {
  static const list = '/services';
  static const newService = '/services/new';
  static String service(int id) => '/services/$id';
}

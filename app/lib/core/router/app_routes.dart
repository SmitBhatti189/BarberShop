/// Paths that are not menu sections (those live in AppDestinations).
abstract final class AppRoutes {
  static const splash = '/';
  static const server = '/server';
  static const login = '/login';

  /// Available to every signed-in user (opened from the profile box).
  static const profile = '/profile';
}

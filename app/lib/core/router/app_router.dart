import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/server_setup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../shared/widgets/placeholder_page.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../../features/profile/presentation/profile_screen.dart';
import 'app_destinations.dart';
import 'app_routes.dart';
import 'app_shell.dart';

export 'app_routes.dart';

/// Pure redirect rule (unit-tested): where should [location] go for [auth]?
String? resolveRedirect(AuthState auth, String location) {
  const publicRoutes = {AppRoutes.splash, AppRoutes.server, AppRoutes.login};
  switch (auth) {
    case AuthLoading():
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthNeedsServer():
      return location == AppRoutes.server ? null : AppRoutes.server;
    case AuthSignedOut():
      return location == AppRoutes.login ? null : AppRoutes.login;
    case AuthSignedIn(:final user):
      if (publicRoutes.contains(location)) return AppDestinations.dashboard.path;
      final destination = AppDestinations.forLocation(location);
      if (destination != null && !destination.isVisibleTo(user)) return AppDestinations.dashboard.path;
      return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod → Listenable so GoRouter re-runs redirect on auth changes
  // without rebuilding the router itself.
  final authChanges = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen<AuthState>(authControllerProvider, (_, next) => authChanges.value = next);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authChanges,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => resolveRedirect(authChanges.value, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.server, builder: (_, _) => const ServerSetupScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: AppDestinations.dashboard.path, pageBuilder: _page(const DashboardScreen())),
          GoRoute(path: AppRoutes.profile, pageBuilder: _page(const ProfileScreen())),
          // Modules not built yet render an honest placeholder (see PlaceholderPage).
          for (final d in AppDestinations.all.where((d) => d != AppDestinations.dashboard))
            GoRoute(
              path: d.path,
              pageBuilder: _page(PlaceholderPage(title: d.label, icon: d.icon)),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Shell pages switch without transition animations (lighter, desktop-like).
Page<void> Function(BuildContext, GoRouterState) _page(Widget child) =>
    (context, state) => NoTransitionPage<void>(key: state.pageKey, child: child);

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
import '../../config/assets/app_icons.dart';
import '../../features/compensation/presentation/pay_setup_screen.dart';
import '../../features/inventory/presentation/inventory_list_screen.dart';
import '../../features/inventory/presentation/inventory_routes.dart';
import '../../features/inventory/presentation/product_detail_screen.dart';
import '../../features/inventory/presentation/product_new_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/services/presentation/service_detail_screen.dart';
import '../../features/services/presentation/service_new_screen.dart';
import '../../features/services/presentation/services_list_screen.dart';
import '../../features/services/presentation/services_routes.dart';
import '../../features/staff/presentation/employee_detail_screen.dart';
import '../../features/staff/presentation/employee_new_screen.dart';
import '../../features/staff/presentation/staff_list_screen.dart';
import '../../features/staff/presentation/staff_routes.dart';
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
          GoRoute(
            path: StaffRoutes.list,
            pageBuilder: _page(const StaffListScreen()),
            routes: [
              GoRoute(path: 'new', pageBuilder: _page(const EmployeeNewScreen())),
              GoRoute(path: 'pay', pageBuilder: _page(const PaySetupScreen())),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: id == null
                        ? const PlaceholderPage(title: 'Employee not found', icon: AppIcons.staff)
                        : EmployeeDetailScreen(id: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: InventoryRoutes.list,
            pageBuilder: _page(const InventoryListScreen()),
            routes: [
              GoRoute(path: 'new', pageBuilder: _page(const ProductNewScreen())),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: id == null
                        ? const PlaceholderPage(title: 'Product not found', icon: AppIcons.inventory)
                        : ProductDetailScreen(id: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: ServicesRoutes.list,
            pageBuilder: _page(const ServicesListScreen()),
            routes: [
              GoRoute(path: 'new', pageBuilder: _page(const ServiceNewScreen())),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: id == null
                        ? const PlaceholderPage(title: 'Service not found', icon: AppIcons.services)
                        : ServiceDetailScreen(id: id),
                  );
                },
              ),
            ],
          ),
          // Modules not built yet render an honest placeholder (see PlaceholderPage).
          for (final d in AppDestinations.all.where((d) => !_built.contains(d)))
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

/// Sections with real screens; the rest get the placeholder route.
const _built = {AppDestinations.dashboard, AppDestinations.staff, AppDestinations.inventory, AppDestinations.services};

/// Shell pages switch without transition animations (lighter, desktop-like).
Page<void> Function(BuildContext, GoRouterState) _page(Widget child) =>
    (context, state) => NoTransitionPage<void>(key: state.pageKey, child: child);

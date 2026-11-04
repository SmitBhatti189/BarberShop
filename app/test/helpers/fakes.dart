import 'package:barbershop_app/config/theme/app_theme.dart';
import 'package:barbershop_app/core/auth/auth_controller.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/core/providers.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:barbershop_app/core/ui/ui_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth controller with a scripted state; records login and logout calls.
class FakeAuthController extends AuthController {
  FakeAuthController(this.initial, {this.loginError});

  final AuthState initial;
  final String? loginError;
  final attempts = <(String, String)>[];
  int logouts = 0;

  @override
  AuthState build() => initial;

  @override
  Future<String?> login(String username, String password) async {
    attempts.add((username, password));
    return loginError;
  }

  @override
  Future<void> logout() async {
    logouts++;
    state = const AuthSignedOut();
  }
}

CurrentUser staffUser() => CurrentUser(
  id: 2,
  fullName: 'Asha Rao',
  branchId: 1,
  roleId: 2,
  permissions: {Permissions.appointmentsView, Permissions.billingCreate, Permissions.customersView},
);

CurrentUser managerUser() => CurrentUser(
  id: 1,
  fullName: 'Salon Owner',
  branchId: 1,
  roleId: 1,
  permissions: {Permissions.settingsManage, Permissions.customersView, Permissions.appointmentsView},
);

/// Wraps [child] in a ProviderScope with fake auth and in-memory storage, and
/// a MaterialApp whose theme follows the UI-preferences provider (like the app).
Widget harness(FakeAuthController controller, Widget child, {InMemorySecureStore? store}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => controller),
      secureStoreProvider.overrideWithValue(store ?? InMemorySecureStore()),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(uiPreferencesProvider.select((p) => p.themeMode)),
        home: child,
      ),
    ),
  );
}

import 'package:flutter/foundation.dart';

/// The signed-in staff member, as returned by `GET /auth/me`.
@immutable
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.fullName,
    required this.branchId,
    required this.roleId,
    required this.permissions,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    id: json['id'] as int,
    fullName: json['fullName'] as String,
    branchId: json['branchId'] as int,
    roleId: json['roleId'] as int,
    permissions: Set.unmodifiable((json['permissions'] as List).cast<String>()),
  );

  final int id;
  final String fullName;
  final int branchId;
  final int roleId;

  /// Permission keys granted by the backend. Used ONLY to shape the UI;
  /// the backend re-checks every request.
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
  bool canAny(Iterable<String> keys) => keys.any(permissions.contains);
}

@immutable
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Where the app is in the sign-in lifecycle. The router redirects on this.
sealed class AuthState {
  const AuthState();
}

/// Restoring a saved session on start-up.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No server address configured yet (dev builds on first launch).
class AuthNeedsServer extends AuthState {
  const AuthNeedsServer();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  /// Optional reason shown on the login screen (e.g. session expired).
  final String? message;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final CurrentUser user;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/secure_store.dart';

/// Per-device UI choices: light/dark theme and whether the sidebar is
/// collapsed. Saved locally so they survive restarts. These are personal
/// display preferences, not business data, so they never go to the server.
@immutable
class UiPreferences {
  const UiPreferences({this.themeMode = ThemeMode.system, this.sidebarCollapsed});

  /// `system` until the user picks light or dark.
  final ThemeMode themeMode;

  /// Null until the user toggles it: the shell then picks a default per screen size.
  final bool? sidebarCollapsed;

  UiPreferences copyWith({ThemeMode? themeMode, bool? sidebarCollapsed}) => UiPreferences(
    themeMode: themeMode ?? this.themeMode,
    sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
  );
}

final uiPreferencesProvider = NotifierProvider<UiPreferencesController, UiPreferences>(UiPreferencesController.new);

class UiPreferencesController extends Notifier<UiPreferences> {
  @override
  UiPreferences build() {
    unawaited(_load());
    return const UiPreferences();
  }

  SecureStore get _store => ref.read(secureStoreProvider);

  Future<void> _load() async {
    final theme = await _store.read(SecureStoreKeys.themeMode);
    final collapsed = await _store.read(SecureStoreKeys.sidebarCollapsed);
    state = UiPreferences(
      themeMode: ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system,
      sidebarCollapsed: collapsed == null ? null : collapsed == 'true',
    );
  }

  /// Switches between light and dark, starting from what is on screen now
  /// ([current]) so the first tap always visibly changes the theme.
  Future<void> toggleDarkMode(Brightness current) async {
    final next = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    state = state.copyWith(themeMode: next);
    await _store.write(SecureStoreKeys.themeMode, next.name);
  }

  Future<void> setSidebarCollapsed(bool collapsed) async {
    state = state.copyWith(sidebarCollapsed: collapsed);
    await _store.write(SecureStoreKeys.sidebarCollapsed, '$collapsed');
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_strings.dart';
import 'config/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/ui/ui_preferences.dart';

class BarbershopApp extends ConsumerWidget {
  const BarbershopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(uiPreferencesProvider.select((p) => p.themeMode)),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

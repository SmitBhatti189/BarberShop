import 'package:flutter/material.dart';

import '../../../config/app_strings.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';

/// Centered, width-capped card used by the server-setup and login screens.
class AuthFormFrame extends StatelessWidget {
  const AuthFormFrame({super.key, required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(icon, size: AppSizes.iconXl, color: theme.colorScheme.primary),
                    AppSpacing.gapMd,
                    Text(AppStrings.appName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                    AppSpacing.gapXs,
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    AppSpacing.gapXl,
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

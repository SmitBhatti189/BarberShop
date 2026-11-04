import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_scaffold.dart';

/// Signed-in user's own details, from `GET /auth/me`. Editing the profile and
/// changing the password arrive with staff management (Phase 3a).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final permissions = user.permissions.toList()..sort();

    return PageScaffold(
      title: 'Profile',
      body: ListView(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: theme.textTheme.titleLarge),
                AppSpacing.gapXs,
                Text(
                  'Editing your profile and password will be available with staff management.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your permissions (${permissions.length})', style: theme.textTheme.titleMedium),
                AppSpacing.gapMd,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final p in permissions)
                      Chip(
                        label: Text(p),
                        backgroundColor: colors.secondaryButton,
                        labelStyle: theme.textTheme.labelMedium?.copyWith(color: colors.secondaryText),
                        side: BorderSide.none,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

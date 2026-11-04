import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/page_scaffold.dart';

/// Phase 2 dashboard: confirms who is signed in and what they may access.
/// The permission-aware summary sections are built in Phase 3i.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return PageScaffold(
      title: 'Dashboard',
      body: ListView(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${user.fullName}', style: theme.textTheme.titleLarge),
                AppSpacing.gapXs,
                Text(
                  'You have ${user.permissions.length} permissions. '
                  'Dashboard summaries (sales, appointments, low stock, commission) arrive in a later phase.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

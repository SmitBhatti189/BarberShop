import 'package:flutter/material.dart';

import '../../../../config/assets/app_icons.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_radius.dart';
import '../../../../config/theme/app_sizes.dart';
import '../../../../config/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';

/// Titled card in the dashboard body, with an optional link to the section
/// that holds the full view.
class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.title, required this.child, this.linkLabel, this.onLink});

  final String title;
  final String? linkLabel;
  final VoidCallback? onLink;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: textTheme.titleMedium)),
              if (linkLabel != null && onLink != null)
                TextButton(
                  onPressed: onLink,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(linkLabel!),
                      AppSpacing.gapXs,
                      Icon(AppIcons.forward, size: AppSizes.iconSm, color: colors.secondaryText),
                    ],
                  ),
                )
              else
                const SizedBox(height: AppSizes.buttonHeight),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Body of a card whose module is not built yet: what will appear here and
/// which module brings it. Never a made-up value.
class ComingWithModule extends StatelessWidget {
  const ComingWithModule({super.key, required this.description, required this.module});

  final String description;
  final String module;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: colors.background, borderRadius: AppRadius.button),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.construction, size: AppSizes.iconMd, color: colors.textSecondary),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: textTheme.bodyMedium),
                AppSpacing.gapXs,
                Text(
                  'Appears when the $module module is built.',
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_radius.dart';
import '../../../../config/theme/app_sizes.dart';
import '../../../../config/theme/app_spacing.dart';
import '../../../../config/theme/app_typography.dart';

/// A labelled number at the top of the dashboard. [value] is null until the
/// module that supplies it exists; the tile then shows "—" and [caption]
/// says why. [highlighted] draws the dark tile used for the key figure.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.caption, this.value, this.highlighted = false});

  final String label;
  final String? value;
  final String caption;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final labelColor = highlighted ? colors.sidebarText : colors.textSecondary;
    final valueColor = highlighted ? colors.sidebarTextStrong : colors.textPrimary;

    return Semantics(
      container: true,
      label: '$label: ${value ?? 'not available yet'}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.statTileMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: highlighted ? colors.sidebarBackground : colors.surface,
            borderRadius: AppRadius.card,
            border: highlighted ? null : Border.all(color: colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: textTheme.labelMedium?.copyWith(color: labelColor)),
              AppSpacing.gapXs,
              Text(
                value ?? '—',
                style: textTheme.headlineMedium?.copyWith(
                  color: valueColor,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              AppSpacing.gapXs,
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: labelColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

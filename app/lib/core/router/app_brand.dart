import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_hover_labels.dart';
import '../../config/app_strings.dart';
import '../../config/assets/app_icons.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_radius.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import '../../shared/widgets/hover_label.dart';
import 'app_destinations.dart';

/// Scissors logo, optionally followed by the salon name. Clicking it opens
/// the Dashboard.
class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.showName = true});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return HoverLabel(
      enabled: AppHoverLabels.appName,
      message: AppStrings.appName,
      child: InkWell(
        key: const Key('salon-name'),
        borderRadius: AppRadius.button,
        overlayColor: colors.overlay,
        onTap: () => context.go(AppDestinations.dashboard.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.brand, color: colors.goldButton, size: AppSizes.iconLg),
              if (showName) ...[
                AppSpacing.gapSm,
                Flexible(
                  child: Text(
                    AppStrings.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

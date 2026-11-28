import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_hover_labels.dart';
import '../../config/app_strings.dart';
import '../../config/assets/app_icons.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_radius.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import '../../config/theme/app_typography.dart';
import '../../shared/widgets/hover_label.dart';
import 'app_destinations.dart';

/// Gold square with the scissors icon — the app's logo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = AppSizes.brandMarkSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colors.goldButton, borderRadius: AppRadius.button),
      child: Icon(AppIcons.brand, color: colors.goldButtonText, size: size * 0.53),
    );
  }
}

/// Logo, optionally followed by the salon name in the serif display face.
/// Clicking it opens the Dashboard. [onDark] switches the name to the light
/// text used on the dark side menu.
class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.showName = true, this.onDark = false, this.markSize = AppSizes.brandMarkSize});

  final bool showName;
  final bool onDark;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final nameStyle = AppTypography.brandName.copyWith(color: onDark ? colors.sidebarTextStrong : colors.textPrimary);
    return HoverLabel(
      enabled: AppHoverLabels.appName,
      message: AppStrings.appName,
      child: InkWell(
        key: const Key('salon-name'),
        borderRadius: AppRadius.button,
        overlayColor: onDark ? colors.sidebarOverlay : colors.overlay,
        onTap: () => context.go(AppDestinations.dashboard.path),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: markSize),
              if (showName) ...[
                AppSpacing.gapMd,
                Flexible(
                  child: Text(AppStrings.appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_hover_labels.dart';
import '../../config/assets/app_icons.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_radius.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import '../../shared/widgets/hover_label.dart';
import 'app_brand.dart';
import 'app_destinations.dart';

/// Collapsible side menu (tablet/desktop), full height.
/// * Header: scissors logo (+ salon name when open) and the collapse button
///   on its right. Clicking the logo opens the Dashboard.
/// * Open: icon + label per section.
/// * Collapsed: icons only; hovering shows the section name (see
///   `AppHoverLabels.sidebarItems`) and clicking navigates as usual.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.destinations,
    required this.selected,
    required this.collapsed,
    required this.onToggle,
  });

  final List<AppDestination> destinations;
  final int selected;
  final bool collapsed;
  final VoidCallback onToggle;

  static const _animation = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: _animation,
      curve: Curves.easeOut,
      width: collapsed ? AppSizes.sidebarCollapsedWidth : AppSizes.sidebarExpandedWidth,
      decoration: BoxDecoration(
        color: colors.navigationBackground,
        border: Border(right: BorderSide(color: colors.divider)),
      ),
      child: Column(
        children: [
          _SidebarHeader(collapsed: collapsed, onToggle: onToggle),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
              itemCount: destinations.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _SidebarItem(destination: destinations[i], selected: i == selected, collapsed: collapsed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same height as the navbar so the two line up across the top.
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = collapsed ? 'Expand menu' : 'Collapse menu';
    return Container(
      height: AppSizes.navBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Show the name only once the (animating) width has room for it.
          final showName = constraints.maxWidth > AppSizes.sidebarCollapsedWidth + AppSpacing.xxl;
          return Row(
            children: [
              if (showName)
                const Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: AppBrand()),
                )
              else
                const Expanded(child: Center(child: AppBrand(showName: false))),
              HoverLabel(
                enabled: AppHoverLabels.sidebarToggle,
                message: label,
                child: SizedBox.square(
                  dimension: AppSizes.sidebarToggleSize,
                  child: IconButton(
                    key: const Key('sidebar-toggle'),
                    padding: EdgeInsets.zero,
                    iconSize: AppSizes.iconMd,
                    icon: Icon(collapsed ? AppIcons.menuExpand : AppIcons.menuCollapse, semanticLabel: label),
                    onPressed: onToggle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.destination, required this.selected, required this.collapsed});

  final AppDestination destination;
  final bool selected;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final iconColor = selected ? colors.selectedIcon : colors.unselectedIcon;

    final item = Material(
      color: selected ? colors.selectedItem : Colors.transparent,
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        overlayColor: colors.overlay,
        onTap: () => context.go(destination.path),
        child: SizedBox(
          height: AppSizes.sidebarItemHeight,
          // Labels appear only once there is room, so nothing overflows while
          // the width animates.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showLabel = constraints.maxWidth > AppSizes.sidebarCollapsedWidth + AppSpacing.xl;
              return Row(
                mainAxisAlignment: showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  if (showLabel) AppSpacing.gapMd,
                  Icon(destination.icon, color: iconColor, size: AppSizes.iconLg),
                  if (showLabel) ...[
                    AppSpacing.gapMd,
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: selected ? colors.selectedIcon : colors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );

    return HoverLabel(
      enabled: collapsed && AppHoverLabels.sidebarItems,
      message: destination.label,
      child: Semantics(label: destination.label, selected: selected, button: true, child: item),
    );
  }
}

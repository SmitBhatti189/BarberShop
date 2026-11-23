import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_hover_labels.dart';
import '../../config/assets/app_icons.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_radius.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import '../../config/theme/app_typography.dart';
import '../../shared/widgets/hover_label.dart';
import '../providers.dart';
import '../server/server_address.dart';
import 'app_brand.dart';
import 'app_destinations.dart';

/// Collapsible side menu (tablet/desktop), full height, dark in both themes.
/// * Header: logo (+ salon name when open) and the collapse button on its
///   right. Clicking the logo opens the Dashboard.
/// * Sections are listed under their group label (Front desk, Business, …);
///   while collapsed a thin divider replaces the label.
/// * Collapsed: icons only; hovering shows the section name (see
///   `AppHoverLabels.sidebarItems`) and clicking navigates as usual.
/// * Footer (open only): which salon server the app talks to.
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
    final children = <Widget>[];
    AppNavGroup? group;
    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      if (d.group != group) {
        children.add(_GroupHeader(group: d.group, first: group == null, collapsed: collapsed));
        group = d.group;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: _SidebarItem(destination: d, selected: i == selected, collapsed: collapsed),
        ),
      );
    }

    return AnimatedContainer(
      duration: _animation,
      curve: Curves.easeOut,
      width: collapsed ? AppSizes.sidebarCollapsedWidth : AppSizes.sidebarExpandedWidth,
      color: colors.sidebarBackground,
      child: Column(
        children: [
          _SidebarHeader(collapsed: collapsed, onToggle: onToggle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              children: children,
            ),
          ),
          if (!collapsed) const _ServerFooter(),
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
        border: Border(bottom: BorderSide(color: colors.sidebarDivider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Show the name only once the (animating) width has room for it.
          final showName = constraints.maxWidth > AppSizes.sidebarCollapsedWidth + AppSpacing.xxl;
          return Row(
            children: [
              if (showName)
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: Align(alignment: Alignment.centerLeft, child: AppBrand(onDark: true)),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: AppBrand(showName: false, onDark: true, markSize: AppSizes.brandMarkSmall),
                  ),
                ),
              HoverLabel(
                enabled: AppHoverLabels.sidebarToggle,
                message: label,
                child: SizedBox.square(
                  dimension: AppSizes.sidebarToggleSize,
                  child: IconButton(
                    key: const Key('sidebar-toggle'),
                    padding: EdgeInsets.zero,
                    iconSize: AppSizes.iconMd,
                    color: colors.sidebarMuted,
                    style: ButtonStyle(overlayColor: colors.sidebarOverlay),
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.first, required this.collapsed});

  final AppNavGroup group;
  final bool first;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (collapsed) {
      if (first) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        child: Divider(color: colors.sidebarDivider),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        first ? AppSpacing.sm : AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        group.label.toUpperCase(),
        style: AppTypography.overline.copyWith(color: colors.sidebarMuted),
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
    final foreground = selected ? colors.sidebarSelectedText : colors.sidebarText;

    final item = Material(
      color: selected ? colors.sidebarSelectedBackground : Colors.transparent,
      borderRadius: AppRadius.button,
      child: InkWell(
        borderRadius: AppRadius.button,
        overlayColor: colors.sidebarOverlay,
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
                  Icon(destination.icon, color: foreground, size: AppSizes.iconMd),
                  if (showLabel) ...[
                    AppSpacing.gapMd,
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: foreground,
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

/// "Server · 192.168.1.10:8080" — reminds the salon which PC the app uses.
class _ServerFooter extends ConsumerWidget {
  const _ServerFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final address = displayServerAddress(ref.watch(apiClientProvider).baseUrl);
    if (address == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.sidebarDivider)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.server, size: AppSizes.iconSm, color: colors.sidebarMuted),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              'Server · $address',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.sidebarMuted),
            ),
          ),
        ],
      ),
    );
  }
}

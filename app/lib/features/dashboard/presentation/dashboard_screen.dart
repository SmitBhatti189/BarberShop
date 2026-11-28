import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/dashboard_layout.dart';
import 'widgets/dashboard_card.dart';
import 'widgets/stat_tile.dart';

/// Greeting by time of day: "Good morning" before 12:00, "Good afternoon"
/// before 17:00, otherwise "Good evening".
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// The dashboard: greeting, key numbers, then the day's panels. What appears
/// depends on the person's permissions ([dashboardLayoutFor]): a manager
/// sees the salon, a barber sees their own work.
///
/// No module behind these numbers exists yet, so every tile shows "—" and
/// every panel says which module will fill it (DEVELOPMENT_GUIDELINES: never
/// fake data). Quick actions already open their sections.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final layout = dashboardLayoutFor(user);
    final now = DateTime.now();
    final firstName = user.fullName.trim().split(RegExp(r'\s+')).first;

    final main = [for (final p in layout.mainPanels) _PanelCard(panel: p)];
    final side = [
      if (layout.actions.isNotEmpty) _QuickActions(actions: layout.actions),
      for (final p in layout.sidePanels) _PanelCard(panel: p),
    ];

    return PageScaffold(
      subtitle: DateFormat('EEEE, d MMMM').format(now),
      title: '${greetingFor(now)}, $firstName',
      body: ListView(
        children: [
          if (layout.isEmpty) const EmptyView(message: 'Nothing on your dashboard for your role yet.'),
          if (layout.stats.isNotEmpty) ...[_StatGrid(stats: layout.stats), AppSpacing.gapXl],
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns =
                  constraints.maxWidth >= AppSizes.dashboardTwoColumnMin && main.isNotEmpty && side.isNotEmpty;
              if (!twoColumns) return _Stack(children: [...main, ...side]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _Stack(children: main)),
                  AppSpacing.gapLg,
                  SizedBox(
                    width: AppSizes.dashboardSideWidth,
                    child: _Stack(children: side),
                  ),
                ],
              );
            },
          ),
          AppSpacing.gapXl,
        ],
      ),
    );
  }
}

/// Number tiles: up to four per row, fewer when narrow.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final List<DashboardStat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.lg;
        final fit = ((constraints.maxWidth + gap) / (AppSizes.statTileMinWidth + gap)).floor();
        final columns = fit.clamp(1, 4).clamp(1, stats.length);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in stats)
              SizedBox(
                key: Key('stat-${s.name}'),
                width: width,
                child: StatTile(label: s.label, caption: 'Shows once ${s.module} is built', highlighted: s.highlighted),
              ),
          ],
        );
      },
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.panel});

  final DashboardPanel panel;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      key: Key('panel-${panel.name}'),
      title: panel.title,
      linkLabel: panel.destination.label,
      onLink: () => context.go(panel.destination.path),
      child: ComingWithModule(description: panel.description, module: panel.destination.label),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      key: const Key('panel-quick-actions'),
      title: 'Quick actions',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final (i, a) in actions.indexed)
            AppButton(
              key: Key('action-${a.name}'),
              label: a.label,
              icon: i == 0 ? AppIcons.add : null,
              size: AppButtonSize.small,
              // The first action is the main one (New bill for most people).
              variant: i == 0 ? AppButtonVariant.gold : AppButtonVariant.secondary,
              onPressed: () => context.go(a.destination.path),
            ),
        ],
      ),
    );
  }
}

/// Vertical list of cards with even gaps.
class _Stack extends StatelessWidget {
  const _Stack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) AppSpacing.gapLg, c],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/assets/app_icons.dart';
import '../auth/auth_controller.dart';
import '../responsive/breakpoints.dart';
import '../ui/ui_preferences.dart';
import 'app_destinations.dart';
import 'app_navbar.dart';
import 'app_sidebar.dart';

/// Frame around every signed-in page.
/// * compact (phones): top navbar + bottom bar (4 primary items + "More")
/// * medium / expanded: top navbar + collapsible sidebar. The sidebar starts
///   collapsed on tablets and expanded on desktops until the user toggles it;
///   their choice is then remembered.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return child; // router redirects momentarily
    final destinations = AppDestinations.menuFor(user);
    final current = AppDestinations.forLocation(location);
    final selected = current == null ? -1 : destinations.indexOf(current);
    final layout = context.layoutSize;

    if (layout == LayoutSize.compact) {
      return _CompactShell(destinations: destinations, selected: selected, child: child);
    }

    final saved = ref.watch(uiPreferencesProvider.select((p) => p.sidebarCollapsed));
    final collapsed = saved ?? layout == LayoutSize.medium;
    // Full-height sidebar on the left; navbar + page on the right.
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            destinations: destinations,
            selected: selected,
            collapsed: collapsed,
            onToggle: () => ref.read(uiPreferencesProvider.notifier).setSidebarCollapsed(!collapsed),
          ),
          Expanded(
            child: Column(
              children: [
                const AppNavBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.destinations, required this.selected, required this.child});

  final List<AppDestination> destinations;
  final int selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = destinations.where((d) => d.primaryOnMobile).take(4).toList();
    final overflow = destinations.where((d) => !primary.contains(d)).toList();
    final current = selected >= 0 ? destinations[selected] : null;
    final index = current != null && primary.contains(current) ? primary.indexOf(current) : primary.length;

    return Scaffold(
      appBar: const AppNavBar(compact: true),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i < primary.length) {
            context.go(primary[i].path);
          } else {
            _showMore(context, overflow);
          }
        },
        destinations: [
          for (final d in primary) NavigationDestination(icon: Icon(d.icon), label: d.shortLabel ?? d.label),
          const NavigationDestination(icon: Icon(AppIcons.more), label: 'More'),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<AppDestination> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final d in items)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(d.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

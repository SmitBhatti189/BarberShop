import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/permissions.dart';
import 'staff_routes.dart';

enum StaffSection { employees, pay }

/// "Employees | Commission & salary" switch at the top of Staff & pay.
/// Each tab shows only if the user may see it; with one tab, nothing shows.
class StaffSectionTabs extends ConsumerWidget {
  const StaffSectionTabs({super.key, required this.current});

  final StaffSection current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canEmployees = user?.can(Permissions.staffView) ?? false;
    final canPay = user?.can(Permissions.compensationView) ?? false;
    if (!(canEmployees && canPay)) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<StaffSection>(
        key: const Key('staff-section-tabs'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: StaffSection.employees, label: Text('Employees')),
          ButtonSegment(value: StaffSection.pay, label: Text('Commission & salary')),
        ],
        selected: {current},
        onSelectionChanged: (s) => context.go(s.first == StaffSection.employees ? StaffRoutes.list : StaffRoutes.pay),
      ),
    );
  }
}

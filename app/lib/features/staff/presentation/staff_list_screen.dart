import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_radius.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/permissions.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_pill.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/staff_providers.dart';
import '../domain/employee.dart';
import 'staff_routes.dart';
import 'staff_section_tabs.dart';

/// Staff & pay → Employees: search, filter by status, open or add an employee.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(staffListProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canView = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.staffView) ?? false));
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.staffManage) ?? false));
    final compact = context.layoutSize == LayoutSize.compact;

    return PageScaffold(
      subtitle: 'Staff & pay',
      title: 'Employees',
      actions: [
        if (canManage)
          AppButton(
            key: const Key('add-employee'),
            label: compact ? 'Add' : 'Add employee',
            icon: AppIcons.add,
            onPressed: () => context.go(StaffRoutes.newEmployee),
          ),
      ],
      body: !canView
          ? EmptyView(
              message: 'You do not have permission to see employees.',
              action: ref.watch(currentUserProvider.select((u) => u?.can(Permissions.compensationView) ?? false))
                  ? AppButton(
                      label: 'Open Commission & salary',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.go(StaffRoutes.pay),
                    )
                  : null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StaffSectionTabs(current: StaffSection.employees),
                AppSpacing.gapLg,
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
                      child: AppTextField(
                        key: const Key('employee-search'),
                        label: 'Search name, username or mobile',
                        prefixIcon: AppIcons.search,
                        onChanged: _onSearch,
                      ),
                    ),
                    const _StatusFilter(),
                  ],
                ),
                AppSpacing.gapLg,
                const Expanded(child: _EmployeeList()),
              ],
            ),
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(staffListProvider.select((s) => s.status));
    return SegmentedButton<StatusFilter>(
      showSelectedIcon: false,
      segments: [for (final s in StatusFilter.values) ButtonSegment(value: s, label: Text(s.label))],
      selected: {status},
      onSelectionChanged: (s) => ref.read(staffListProvider.notifier).setStatus(s.first),
    );
  }
}

class _EmployeeList extends ConsumerWidget {
  const _EmployeeList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffListProvider);
    final controller = ref.read(staffListProvider.notifier);

    if (state.loading && state.items.isEmpty) return const LoadingView();
    if (state.error != null && state.items.isEmpty) {
      return ErrorView(message: state.error!.message, onRetry: controller.reload);
    }
    if (state.items.isEmpty) {
      return EmptyView(
        message: state.search.isNotEmpty
            ? 'No employees match "${state.search}".'
            : state.status == StatusFilter.inactive
            ? 'No inactive employees.'
            : 'No employees yet. Add your first one to get started.',
      );
    }

    final wide = context.layoutSize != LayoutSize.compact;
    return ListView.separated(
      itemCount: state.items.length + (state.hasMore ? 1 : 0) + (wide ? 1 : 0),
      separatorBuilder: (_, _) => AppSpacing.gapSm,
      itemBuilder: (context, index) {
        if (wide && index == 0) return const _HeaderRow();
        final i = wide ? index - 1 : index;
        if (i == state.items.length) {
          return Center(
            child: AppButton(
              label: 'Show more (${state.total - state.items.length} left)',
              variant: AppButtonVariant.text,
              loading: state.loadingMore,
              onPressed: controller.loadMore,
            ),
          );
        }
        return _EmployeeRow(employee: state.items[i], wide: wide);
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.of(context).textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('NAME', style: style)),
          Expanded(flex: 2, child: Text('ROLE', style: style)),
          Expanded(flex: 2, child: Text('MOBILE', style: style)),
          Expanded(flex: 2, child: Text('SIGN-IN', style: style)),
          const SizedBox(width: AppSizes.iconLg),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee, required this.wide});

  final Employee employee;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final e = employee;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    final signIn = e.canSignIn ? e.username! : 'No login';

    final name = Row(
      children: [
        _Initials(name: e.fullName, dimmed: !e.isActive),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(e.fullName, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  ),
                  if (!e.isActive) ...[AppSpacing.gapSm, const StatusPill(active: false)],
                ],
              ),
              if (!wide)
                Text(
                  [e.roleName, if (e.mobile != null) e.mobile!, if (!e.canSignIn) 'No login'].join(' · '),
                  style: muted,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: colors.divider),
      ),
      child: InkWell(
        key: Key('employee-${e.id}'),
        borderRadius: AppRadius.card,
        overlayColor: colors.overlay,
        onTap: () => context.go(StaffRoutes.employee(e.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(flex: 4, child: name),
              if (wide) ...[
                Expanded(flex: 2, child: Text(e.roleName, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(e.mobile ?? '—', style: muted)),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(
                        e.canSignIn ? AppIcons.login : AppIcons.noLogin,
                        size: AppSizes.iconSm,
                        color: colors.unselectedIcon,
                      ),
                      AppSpacing.gapXs,
                      Flexible(
                        child: Text(signIn, style: muted, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
              Icon(AppIcons.chevronRight, color: colors.unselectedIcon),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, this.dimmed = false});

  final String name;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: AppSizes.avatarSize / 2,
      backgroundColor: dimmed ? colors.disabledBackground : colors.secondaryButton,
      child: Text(
        initials,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: dimmed ? colors.disabledText : colors.secondaryText),
      ),
    );
  }
}

/// "Active" / "Inactive" chip.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppPill(label: active ? 'Active' : 'Inactive', color: active ? colors.success : colors.disabledText);
  }
}

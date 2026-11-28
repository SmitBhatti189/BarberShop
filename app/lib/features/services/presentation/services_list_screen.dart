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
import '../../../core/utils/money_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_pill.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/services_providers.dart';
import '../domain/salon_service.dart';
import 'services_routes.dart';

/// Services: everything the salon offers, with price and duration.
class ServicesListScreen extends ConsumerStatefulWidget {
  const ServicesListScreen({super.key});

  @override
  ConsumerState<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends ConsumerState<ServicesListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(servicesListProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.servicesManage) ?? false));
    final compact = context.layoutSize == LayoutSize.compact;

    return PageScaffold(
      subtitle: 'Business',
      title: 'Services',
      actions: [
        if (canManage)
          AppButton(
            key: const Key('add-service'),
            label: compact ? 'Add' : 'Add service',
            icon: AppIcons.add,
            onPressed: () => context.go(ServicesRoutes.newService),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
                child: AppTextField(
                  key: const Key('service-search'),
                  label: 'Search service or category',
                  prefixIcon: AppIcons.search,
                  onChanged: _onSearch,
                ),
              ),
              const _CategoryFilter(),
              const _StatusFilter(),
            ],
          ),
          AppSpacing.gapLg,
          const Expanded(child: _ServiceList()),
        ],
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(serviceCategoriesProvider).value ?? const [];
    final selected = ref.watch(servicesListProvider.select((s) => s.category));
    if (categories.isEmpty && selected == null) return const SizedBox.shrink();
    return DropdownMenu<String?>(
      key: const Key('service-category-filter'),
      initialSelection: selected,
      label: const Text('Category'),
      width: AppSizes.dashboardSideWidth * 0.6,
      onSelected: (v) => ref.read(servicesListProvider.notifier).setCategory(v),
      dropdownMenuEntries: [
        const DropdownMenuEntry<String?>(value: null, label: 'All categories'),
        for (final c in categories) DropdownMenuEntry<String?>(value: c, label: c),
      ],
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(servicesListProvider.select((s) => s.status));
    return SegmentedButton<StatusFilter>(
      showSelectedIcon: false,
      segments: [for (final s in StatusFilter.values) ButtonSegment(value: s, label: Text(s.label))],
      selected: {status},
      onSelectionChanged: (s) => ref.read(servicesListProvider.notifier).setStatus(s.first),
    );
  }
}

class _ServiceList extends ConsumerWidget {
  const _ServiceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(servicesListProvider);
    if (state.loading && state.items.isEmpty) return const LoadingView();
    if (state.error != null && state.items.isEmpty) {
      return ErrorView(message: state.error!.message, onRetry: ref.read(servicesListProvider.notifier).reload);
    }
    if (state.items.isEmpty) {
      return EmptyView(
        message: state.filtered
            ? 'No services match these filters.'
            : 'No services yet. Add what you offer, like Haircut or Beard trim, with its price.',
      );
    }
    final wide = context.layoutSize != LayoutSize.compact;
    return ListView.separated(
      itemCount: state.items.length + (wide ? 1 : 0),
      separatorBuilder: (_, _) => AppSpacing.gapSm,
      itemBuilder: (context, index) {
        if (wide && index == 0) return const _HeaderRow();
        return _ServiceRow(service: state.items[wide ? index - 1 : index], wide: wide);
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
          Expanded(flex: 5, child: Text('SERVICE', style: style)),
          Expanded(flex: 2, child: Text('CATEGORY', style: style)),
          Expanded(
            flex: 2,
            child: Text('DURATION', style: style, textAlign: TextAlign.end),
          ),
          Expanded(
            flex: 2,
            child: Text('PRICE', style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: AppSizes.iconLg + AppSpacing.md),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.wide});

  final SalonService service;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final s = service;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    final number = theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(s.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
            ),
            if (!s.isActive) ...[AppSpacing.gapSm, AppPill(label: 'Inactive', color: colors.disabledText)],
          ],
        ),
        if (wide && s.description != null)
          Text(s.description!, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (!wide)
          Text(
            [if (s.category != null) s.category!, formatDuration(s.durationMinutes), formatMoney(s.price)].join(' · '),
            style: muted,
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
        key: Key('service-${s.id}'),
        borderRadius: AppRadius.card,
        overlayColor: colors.overlay,
        onTap: () => context.go(ServicesRoutes.service(s.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(flex: 5, child: title),
              if (wide) ...[
                Expanded(
                  flex: 2,
                  child: Text(s.category ?? '—', style: muted, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Text(formatDuration(s.durationMinutes), style: number, textAlign: TextAlign.end),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatMoney(s.price),
                    textAlign: TextAlign.end,
                    style: number?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                AppSpacing.gapMd,
              ],
              Icon(AppIcons.chevronRight, color: colors.unselectedIcon),
            ],
          ),
        ),
      ),
    );
  }
}

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
import '../application/inventory_providers.dart';
import '../domain/product.dart';
import 'inventory_routes.dart';

/// Inventory: every product with its stock, prices and low-stock state.
class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(inventoryListProvider.notifier).setSearch(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.inventoryManage) ?? false));
    final compact = context.layoutSize == LayoutSize.compact;

    return PageScaffold(
      subtitle: 'Business',
      title: 'Inventory',
      actions: [
        if (canManage)
          AppButton(
            key: const Key('add-product'),
            label: compact ? 'Add' : 'Add product',
            icon: AppIcons.add,
            onPressed: () => context.go(InventoryRoutes.newProduct),
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
                  key: const Key('product-search'),
                  label: 'Search product or brand',
                  prefixIcon: AppIcons.search,
                  onChanged: _onSearch,
                ),
              ),
              const _CategoryFilter(),
              const _StatusFilter(),
              const _LowStockFilter(),
            ],
          ),
          AppSpacing.gapLg,
          const Expanded(child: _ProductList()),
        ],
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(productSuggestionsProvider).value?.categories ?? const [];
    final selected = ref.watch(inventoryListProvider.select((s) => s.category));
    if (categories.isEmpty && selected == null) return const SizedBox.shrink();
    return DropdownMenu<String?>(
      key: const Key('category-filter'),
      initialSelection: selected,
      label: const Text('Category'),
      width: AppSizes.dashboardSideWidth * 0.6,
      onSelected: (v) => ref.read(inventoryListProvider.notifier).setCategory(v),
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
    final status = ref.watch(inventoryListProvider.select((s) => s.status));
    return SegmentedButton<StatusFilter>(
      showSelectedIcon: false,
      segments: [for (final s in StatusFilter.values) ButtonSegment(value: s, label: Text(s.label))],
      selected: {status},
      onSelectionChanged: (s) => ref.read(inventoryListProvider.notifier).setStatus(s.first),
    );
  }
}

class _LowStockFilter extends ConsumerWidget {
  const _LowStockFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(inventoryListProvider.select((s) => s.lowStockOnly));
    return FilterChip(
      key: const Key('low-stock-filter'),
      label: const Text('Low stock only'),
      selected: on,
      onSelected: (v) => ref.read(inventoryListProvider.notifier).setLowStockOnly(v),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryListProvider);
    final controller = ref.read(inventoryListProvider.notifier);

    if (state.loading && state.items.isEmpty) return const LoadingView();
    if (state.error != null && state.items.isEmpty) {
      return ErrorView(message: state.error!.message, onRetry: controller.reload);
    }
    if (state.items.isEmpty) {
      return EmptyView(
        message: state.filtered
            ? 'No products match these filters.'
            : 'No products yet. Add the products you sell to start tracking stock.',
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
        return _ProductRow(product: state.items[i], wide: wide);
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.of(context).textSecondary);
    Widget cell(String text, int flex, {bool end = false}) => Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: end ? TextAlign.end : TextAlign.start),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          cell('PRODUCT', 4),
          cell('CATEGORY', 2),
          cell('IN STOCK', 2, end: true),
          cell('MRP', 2, end: true),
          cell('DISCOUNT', 2, end: true),
          cell('SELLS AT', 2, end: true),
          const SizedBox(width: AppSizes.iconLg + AppSpacing.md),
        ],
      ),
    );
  }
}

/// "Low stock" / "Out of stock" / "Inactive" label, or nothing.
class StockStatePill extends StatelessWidget {
  const StockStatePill({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (!product.isActive) return AppPill(label: 'Inactive', color: colors.disabledText);
    if (product.stockQuantity <= 0) return AppPill(label: 'Out of stock', color: colors.error);
    if (product.isLowStock) return AppPill(label: 'Low stock', color: colors.warning);
    return const SizedBox.shrink();
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.wide});

  final Product product;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final p = product;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    final number = theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    Widget end(String text, {TextStyle? style}) => Expanded(
      flex: 2,
      child: Text(text, textAlign: TextAlign.end, style: style ?? number),
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(p.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
            ),
            AppSpacing.gapSm,
            StockStatePill(product: p),
          ],
        ),
        if (wide && p.brand != null) Text(p.brand!, style: muted, overflow: TextOverflow.ellipsis),
        if (!wide)
          Text(
            [
              if (p.brand != null) p.brand!,
              '${p.stockQuantity} in stock',
              'sells at ${formatMoney(p.sellingPrice)}',
            ].join(' · '),
            style: muted,
            overflow: TextOverflow.ellipsis,
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
        key: Key('product-${p.id}'),
        borderRadius: AppRadius.card,
        overlayColor: colors.overlay,
        onTap: () => context.go(InventoryRoutes.product(p.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(flex: 4, child: title),
              if (wide) ...[
                Expanded(
                  flex: 2,
                  child: Text(p.category ?? '—', style: muted, overflow: TextOverflow.ellipsis),
                ),
                end(
                  '${p.stockQuantity}',
                  style: number?.copyWith(fontWeight: FontWeight.w600, color: p.isLowStock ? colors.warning : null),
                ),
                end(formatMoney(p.mrp)),
                end(formatPercent(p.defaultDiscountPct)),
                end(formatMoney(p.sellingPrice), style: number?.copyWith(fontWeight: FontWeight.w600)),
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

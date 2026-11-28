import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions.dart';
import '../../../core/utils/money_format.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/scroll_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/inventory_providers.dart';
import '../domain/product.dart';
import 'inventory_list_screen.dart' show StockStatePill;
import 'inventory_routes.dart';
import 'product_form.dart';
import 'stock_dialogs.dart';

/// One product: edit details and prices, receive or adjust stock, see history.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(id));
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.inventoryManage) ?? false));
    return PageScaffold(
      subtitle: 'Inventory',
      title: product.value?.name ?? 'Product',
      actions: [
        AppButton(
          label: 'Back',
          icon: AppIcons.back,
          variant: AppButtonVariant.text,
          onPressed: () => context.go(InventoryRoutes.list),
        ),
      ],
      body: product.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Could not load this product.',
          onRetry: () => ref.invalidate(productProvider(id)),
        ),
        data: (p) => _Body(product: p, canManage: canManage),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.product, required this.canManage});

  final Product product;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Product', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapLg,
          ProductForm(
            key: ValueKey('product-form-${product.id}-${product.version}'),
            initial: product,
            readOnly: !canManage,
            submitLabel: 'Save changes',
            onSubmit: (draft, _) => _save(context, ref, draft),
          ),
        ],
      ),
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StockCard(product: product, canManage: canManage),
        if (canManage) ...[AppSpacing.gapLg, _StatusCard(product: product)],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= AppSizes.dashboardTwoColumnMin;
        return ScrollBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (twoColumns)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    AppSpacing.gapLg,
                    SizedBox(width: AppSizes.dashboardSideWidth, child: side),
                  ],
                )
              else ...[
                details,
                AppSpacing.gapLg,
                side,
              ],
              AppSpacing.gapLg,
              _History(productId: product.id),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String>?> _save(BuildContext context, WidgetRef ref, ProductDraft draft) async {
    try {
      await ref.read(inventoryApiProvider).update(product.id, product.version, draft);
      ref
        ..invalidate(productProvider(product.id))
        ..invalidate(productSuggestionsProvider)
        ..invalidate(inventoryListProvider);
      if (context.mounted) showAppMessage(context, 'Changes saved');
      return null;
    } on ApiException catch (e) {
      if (e.code == 'STALE') ref.invalidate(productProvider(product.id));
      final fields = formFieldErrors(e);
      if (fields.isEmpty && context.mounted) showAppMessage(context, e.message, error: true);
      return fields;
    }
  }
}

class _StockCard extends ConsumerWidget {
  const _StockCard({required this.product, required this.canManage});

  final Product product;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final p = product;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary);

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: muted)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Stock', style: theme.textTheme.titleMedium)),
              StockStatePill(product: p),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            '${p.stockQuantity}',
            key: const Key('stock-quantity'),
            style: theme.textTheme.displaySmall?.copyWith(color: p.isLowStock ? colors.warning : null),
          ),
          Text('units in stock · alert at ${p.lowStockThreshold}', style: muted),
          AppSpacing.gapMd,
          line('Sells at', formatMoney(p.sellingPrice)),
          line('MRP', formatMoney(p.mrp)),
          line('Default discount', formatPercent(p.defaultDiscountPct)),
          line('Last buying price', formatMoney(p.lastPurchasePrice)),
          if (canManage && p.isActive) ...[
            AppSpacing.gapLg,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  key: const Key('receive-stock'),
                  label: 'Receive stock',
                  icon: AppIcons.add,
                  size: AppButtonSize.small,
                  onPressed: () => _open(context, ref, ReceiveStockDialog(product: p), 'Stock added'),
                ),
                AppButton(
                  key: const Key('adjust-stock'),
                  label: 'Adjust stock',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _open(context, ref, AdjustStockDialog(product: p), 'Stock adjusted'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Widget dialog, String success) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => dialog);
    if (saved != true) return;
    ref
      ..invalidate(productProvider(product.id))
      ..invalidate(movementsProvider(product.id))
      ..invalidate(inventoryListProvider);
    if (context.mounted) showAppMessage(context, success);
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = product.isActive;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(active ? 'Stop selling' : 'Sell again', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSm,
          Text(
            active
                ? 'Hides this product from billing and the default list. Its stock history stays.'
                : 'Shows this product in billing and the list again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.of(context).textSecondary),
          ),
          AppSpacing.gapLg,
          AppButton(
            key: const Key('toggle-product-active'),
            label: active ? 'Deactivate product' : 'Reactivate product',
            variant: active ? AppButtonVariant.danger : AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () async {
              if (active) {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Deactivate ${product.name}?',
                  message: 'It will no longer appear in billing. You can reactivate it later.',
                  confirmLabel: 'Deactivate',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
              }
              try {
                await ref.read(inventoryApiProvider).setActive(product.id, !active);
                ref.invalidate(productProvider(product.id));
                ref.invalidate(inventoryListProvider);
                if (context.mounted) showAppMessage(context, active ? 'Product deactivated' : 'Product reactivated');
              } on ApiException catch (e) {
                if (context.mounted) showAppMessage(context, e.message, error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.productId});

  final int productId;

  static final _date = DateFormat('d MMM y, h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movementsProvider(productId));
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary);

    Widget body;
    if (state.loading) {
      body = const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LoadingView());
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorView(message: state.error!.message, onRetry: ref.read(movementsProvider(productId).notifier).reload);
    } else if (state.items.isEmpty) {
      body = Text('No stock movements yet. Use "Receive stock" when a delivery arrives.', style: muted);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in state.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSizes.statTileMinWidth / 2,
                  child: Text(
                    m.quantityDelta > 0 ? '+${m.quantityDelta}' : '${m.quantityDelta}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: m.quantityDelta > 0 ? colors.success : colors.error,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title(m), style: theme.textTheme.bodyMedium),
                      Text('${_date.format(m.createdAt)} · ${m.createdBy}', style: muted),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
          ],
          if (state.nextCursor != null)
            Center(
              child: AppButton(
                label: 'Show older',
                variant: AppButtonVariant.text,
                loading: state.loadingMore,
                onPressed: ref.read(movementsProvider(productId).notifier).loadMore,
              ),
            ),
        ],
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stock history', style: theme.textTheme.titleMedium),
          AppSpacing.gapLg,
          body,
        ],
      ),
    );
  }

  static String _title(StockMovement m) {
    final parts = <String>[
      switch (m.type) {
        MovementType.purchase => 'Delivery at ${formatMoney(m.unitCost)} each',
        MovementType.adjustment => 'Adjustment · ${AdjustmentReason.labelFor(m.reason)}',
        _ => m.type.label,
      },
      if (m.supplierName != null) m.supplierName!,
      if (m.invoiceNo != null) 'bill ${m.invoiceNo}',
      if (m.note != null) m.note!,
    ];
    return parts.join(' · ');
  }
}

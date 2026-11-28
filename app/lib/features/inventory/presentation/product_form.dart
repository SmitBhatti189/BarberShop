import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/suggestion_chips.dart';
import '../application/inventory_providers.dart';
import '../domain/product.dart';

/// Returns server field errors to show, or null on success.
typedef ProductSubmit = Future<Map<String, String>?> Function(ProductDraft draft, PurchaseDraft? openingStock);

/// Product form shared by "Add product" (with optional opening stock) and the
/// product page. Wide screens: product details left, opening stock + save
/// right; narrow screens: stacked.
class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.initial,
    this.includeOpeningStock = false,
    this.readOnly = false,
  });

  final Product? initial;
  final ProductSubmit onSubmit;
  final String submitLabel;
  final bool includeOpeningStock;
  final bool readOnly;

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _brand = TextEditingController(text: widget.initial?.brand);
  late final _category = TextEditingController(text: widget.initial?.category);
  late final _mrp = TextEditingController(text: _plain(widget.initial?.mrp));
  late final _discount = TextEditingController(text: _plain(widget.initial?.defaultDiscountPct) ?? '0');
  late final _threshold = TextEditingController(text: '${widget.initial?.lowStockThreshold ?? 0}');
  final _qty = TextEditingController();
  final _unitCost = TextEditingController();
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  bool _busy = false;
  Map<String, String> _serverErrors = const {};

  late final _all = [_name, _brand, _category, _mrp, _discount, _threshold, _qty, _unitCost, _supplier, _invoice];

  @override
  void initState() {
    super.initState();
    // Rebuild for the live selling-price line and the suggestion chips.
    for (final c in [_brand, _category, _mrp, _discount]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  /// "2000.00" → "2000", "12.50" → "12.5" for editing.
  static String? _plain(String? v) {
    if (v == null) return null;
    final d = double.tryParse(v);
    if (d == null) return v;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  static String? _orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// What the selling price will be, shown while typing. The server computes
  /// the real value with the same rule when the product is saved.
  String? get _sellingPreview {
    final mrp = double.tryParse(_mrp.text.trim());
    final pct = double.tryParse(_discount.text.trim().isEmpty ? '0' : _discount.text.trim());
    if (mrp == null || pct == null || pct < 0 || pct > 100) return null;
    final paise = (mrp * 100).round();
    final discount = (paise * pct / 100).round();
    return ((paise - discount) / 100).toStringAsFixed(2);
  }

  bool get _hasOpeningStock => _qty.text.trim().isNotEmpty || _unitCost.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _serverErrors = const {};
    });
    final errors = await widget.onSubmit(
      ProductDraft(
        name: _name.text.trim(),
        brand: _orNull(_brand),
        category: _orNull(_category),
        mrp: _mrp.text.trim(),
        defaultDiscountPct: _discount.text.trim().isEmpty ? '0' : _discount.text.trim(),
        lowStockThreshold: int.tryParse(_threshold.text.trim()) ?? 0,
      ),
      widget.includeOpeningStock && _hasOpeningStock
          ? PurchaseDraft(
              quantity: int.parse(_qty.text.trim()),
              unitCost: _unitCost.text.trim(),
              supplierName: _orNull(_supplier),
              invoiceNo: _orNull(_invoice),
            )
          : null,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _serverErrors = errors ?? const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.readOnly && !_busy;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final suggestions = ref.watch(productSuggestionsProvider).value;
    final preview = _sellingPreview;

    final details = <Widget>[
      AppTextField(
        key: const Key('product-name'),
        label: 'Product name',
        hint: 'e.g. Anti-dandruff shampoo 200 ml',
        prefixIcon: AppIcons.inventory,
        controller: _name,
        enabled: enabled,
        errorText: _serverErrors['name'],
        validator: (v) => Validators.required(v, 'Enter a product name'),
      ),
      AppSpacing.gapLg,
      AppTextField(
        key: const Key('product-brand'),
        label: 'Brand (optional)',
        controller: _brand,
        enabled: enabled,
        errorText: _serverErrors['brand'],
      ),
      if (enabled) SuggestionChips(options: suggestions?.brands ?? const [], controller: _brand),
      AppSpacing.gapLg,
      AppTextField(
        key: const Key('product-category'),
        label: 'Category (optional)',
        hint: 'e.g. Shampoo, Hair oil, Wax',
        controller: _category,
        enabled: enabled,
        errorText: _serverErrors['category'],
      ),
      if (enabled) SuggestionChips(options: suggestions?.categories ?? const [], controller: _category),
      AppSpacing.gapLg,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              key: const Key('product-mrp'),
              label: 'MRP (₹)',
              controller: _mrp,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              errorText: _serverErrors['mrp'],
              validator: (v) => Validators.money(v, positive: true),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: AppTextField(
              key: const Key('product-discount'),
              label: 'Default discount %',
              controller: _discount,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              errorText: _serverErrors['defaultDiscountPct'],
              validator: Validators.percent,
            ),
          ),
        ],
      ),
      AppSpacing.gapSm,
      Text(
        preview == null ? 'Selling price: enter the MRP' : 'Selling price to customers: ${formatMoney(preview)}',
        key: const Key('selling-preview'),
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w600),
      ),
      AppSpacing.gapLg,
      AppTextField(
        key: const Key('product-threshold'),
        label: 'Low-stock alert at (units)',
        hint: 'Warn when stock falls to this',
        controller: _threshold,
        enabled: enabled,
        keyboardType: TextInputType.number,
        errorText: _serverErrors['lowStockThreshold'],
        validator: (v) => Validators.wholeNumber(v, min: 0),
      ),
    ];

    final submit = Align(
      alignment: Alignment.centerLeft,
      child: AppButton(key: const Key('product-submit'), label: widget.submitLabel, onPressed: _submit, loading: _busy),
    );

    if (!widget.includeOpeningStock) {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...details,
            if (!widget.readOnly) ...[AppSpacing.gapXl, submit],
          ],
        ),
      );
    }

    final titleStyle = theme.textTheme.titleMedium;
    final detailsCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Product', style: titleStyle),
          AppSpacing.gapLg,
          ...details,
        ],
      ),
    );
    final stockCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Opening stock', style: titleStyle),
          AppSpacing.gapXs,
          Text(
            'Optional. Units already on your shelf, recorded as the first delivery.',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          AppSpacing.gapLg,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  key: const Key('opening-qty'),
                  label: 'Quantity',
                  controller: _qty,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  errorText: _serverErrors['quantity'],
                  validator: (v) => _hasOpeningStock ? Validators.wholeNumber(v) : null,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: AppTextField(
                  key: const Key('opening-cost'),
                  label: 'Buying price / unit (₹)',
                  controller: _unitCost,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: _serverErrors['unitCost'],
                  validator: (v) => _hasOpeningStock ? Validators.money(v) : null,
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          AppTextField(label: 'Supplier (optional)', controller: _supplier, enabled: enabled),
          AppSpacing.gapLg,
          AppTextField(label: 'Supplier bill / invoice no. (optional)', controller: _invoice, enabled: enabled),
          if (!widget.readOnly) ...[AppSpacing.gapXl, submit],
        ],
      ),
    );

    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= AppSizes.employeeFormTwoColumnMin
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: detailsCard),
                  AppSpacing.gapLg,
                  Expanded(child: stockCard),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [detailsCard, AppSpacing.gapLg, stockCard],
              ),
      ),
    );
  }
}

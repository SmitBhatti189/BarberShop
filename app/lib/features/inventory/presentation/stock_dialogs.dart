import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/inventory_providers.dart';
import '../domain/product.dart';

/// "Receive stock": a delivery adds units and records this lot's buying price.
/// Resolves to true when saved.
class ReceiveStockDialog extends ConsumerStatefulWidget {
  const ReceiveStockDialog({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ReceiveStockDialog> createState() => _ReceiveStockDialogState();
}

class _ReceiveStockDialogState extends ConsumerState<ReceiveStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _message; // shown inside the dialog

  @override
  void dispose() {
    for (final c in [_qty, _cost, _supplier, _invoice, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryApiProvider)
          .receive(
            widget.product.id,
            PurchaseDraft(
              quantity: int.parse(_qty.text.trim()),
              unitCost: _cost.text.trim(),
              supplierName: _orNull(_supplier),
              invoiceNo: _orNull(_invoice),
              note: _orNull(_note),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = formFieldErrors(e);
        _message = _errors.isEmpty ? e.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      error: _message,
      title: 'Receive stock · ${widget.product.name}',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    key: const Key('receive-qty'),
                    label: 'Quantity',
                    controller: _qty,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    errorText: _errors['quantity'],
                    validator: (v) => Validators.wholeNumber(v),
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: AppTextField(
                    key: const Key('receive-cost'),
                    label: 'Buying price / unit (₹)',
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    errorText: _errors['unitCost'],
                    validator: (v) => Validators.money(v),
                  ),
                ),
              ],
            ),
            AppSpacing.gapLg,
            AppTextField(label: 'Supplier (optional)', controller: _supplier),
            AppSpacing.gapLg,
            AppTextField(label: 'Supplier bill / invoice no. (optional)', controller: _invoice),
            AppSpacing.gapLg,
            AppTextField(label: 'Note (optional)', controller: _note),
          ],
        ),
      ),
      actions: [
        AppButton(label: 'Cancel', variant: AppButtonVariant.text, onPressed: () => Navigator.of(context).pop(false)),
        AppButton(key: const Key('receive-save'), label: 'Add to stock', loading: _busy, onPressed: _save),
      ],
    );
  }
}

/// "Adjust stock": a manual correction in or out, always with a reason.
class AdjustStockDialog extends ConsumerStatefulWidget {
  const AdjustStockDialog({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<AdjustStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _stockIn = false;
  AdjustmentReason? _reason;
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _message; // shown inside the dialog

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(inventoryApiProvider)
          .adjust(
            widget.product.id,
            stockIn: _stockIn,
            quantity: int.parse(_qty.text.trim()),
            reason: _reason!,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = formFieldErrors(e);
        _message = _errors.isEmpty ? e.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AppDialog(
      error: _message,
      title: 'Adjust stock · ${widget.product.name}',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Now in stock: ${widget.product.stockQuantity}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            AppSpacing.gapMd,
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Take out')),
                ButtonSegment(value: true, label: Text('Add in')),
              ],
              selected: {_stockIn},
              onSelectionChanged: (s) => setState(() => _stockIn = s.first),
            ),
            AppSpacing.gapLg,
            AppTextField(
              key: const Key('adjust-qty'),
              label: 'Quantity',
              controller: _qty,
              keyboardType: TextInputType.number,
              errorText: _errors['quantity'],
              validator: (v) => Validators.wholeNumber(v),
            ),
            AppSpacing.gapLg,
            AppDropdown<AdjustmentReason>(
              key: const Key('adjust-reason'),
              label: 'Reason',
              items: AdjustmentReason.values,
              itemLabel: (r) => r.label,
              value: _reason,
              onChanged: (r) => setState(() => _reason = r),
              validator: (r) => r == null ? 'Choose a reason' : null,
            ),
            AppSpacing.gapLg,
            AppTextField(
              key: const Key('adjust-note'),
              label: _reason == AdjustmentReason.other ? 'What happened?' : 'Note (optional)',
              controller: _note,
              errorText: _errors['note'],
              validator: (v) => _reason == AdjustmentReason.other ? Validators.required(v, 'Say what happened') : null,
            ),
          ],
        ),
      ),
      actions: [
        AppButton(label: 'Cancel', variant: AppButtonVariant.text, onPressed: () => Navigator.of(context).pop(false)),
        AppButton(key: const Key('adjust-save'), label: 'Save adjustment', loading: _busy, onPressed: _save),
      ],
    );
  }
}

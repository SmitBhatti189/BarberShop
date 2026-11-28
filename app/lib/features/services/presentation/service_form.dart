import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/suggestion_chips.dart';
import '../application/services_providers.dart';
import '../domain/salon_service.dart';

/// Returns server field errors to show, or null on success.
typedef ServiceSubmit = Future<Map<String, String>?> Function(ServiceDraft draft);

/// Service details form, shared by "Add service" and the service page.
class ServiceForm extends ConsumerStatefulWidget {
  const ServiceForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.initial,
    this.readOnly = false,
  });

  final SalonService? initial;
  final ServiceSubmit onSubmit;
  final String submitLabel;
  final bool readOnly;

  @override
  ConsumerState<ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends ConsumerState<ServiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _category = TextEditingController(text: widget.initial?.category);
  late final _price = TextEditingController(text: _plain(widget.initial?.price));
  late final _duration = TextEditingController(text: widget.initial?.durationMinutes.toString());
  late final _description = TextEditingController(text: widget.initial?.description);
  bool _busy = false;
  Map<String, String> _serverErrors = const {};

  /// Common lengths offered as one-tap chips.
  static const _quickDurations = [15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    for (final c in [_category, _duration]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _category, _price, _duration, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _plain(String? v) {
    if (v == null) return null;
    final d = double.tryParse(v);
    if (d == null) return v;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  static String? _orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _serverErrors = const {};
    });
    final errors = await widget.onSubmit(
      ServiceDraft(
        name: _name.text.trim(),
        category: _orNull(_category),
        description: _orNull(_description),
        price: _price.text.trim(),
        durationMinutes: int.parse(_duration.text.trim()),
      ),
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
    final categories = ref.watch(serviceCategoriesProvider).value ?? const [];
    final selectedDuration = int.tryParse(_duration.text.trim());

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            key: const Key('service-name'),
            label: 'Service name',
            hint: 'e.g. Haircut, Beard trim, Haircut + Beard',
            prefixIcon: AppIcons.services,
            controller: _name,
            enabled: enabled,
            errorText: _serverErrors['name'],
            validator: (v) => Validators.required(v, 'Enter a service name'),
          ),
          AppSpacing.gapLg,
          AppTextField(
            key: const Key('service-category'),
            label: 'Category (optional)',
            hint: 'e.g. Hair, Beard, Facial',
            controller: _category,
            enabled: enabled,
            errorText: _serverErrors['category'],
          ),
          if (enabled) SuggestionChips(options: categories, controller: _category),
          AppSpacing.gapLg,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  key: const Key('service-price'),
                  label: 'Price (₹)',
                  controller: _price,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  errorText: _serverErrors['price'],
                  validator: (v) => Validators.money(v),
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: AppTextField(
                  key: const Key('service-duration'),
                  label: 'Duration (minutes)',
                  controller: _duration,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  errorText: _serverErrors['durationMinutes'],
                  validator: (v) {
                    final error = Validators.wholeNumber(v);
                    if (error != null) return error;
                    return int.parse(v!.trim()) > 600 ? 'At most 600 minutes' : null;
                  },
                ),
              ),
            ],
          ),
          if (enabled) ...[
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final m in _quickDurations)
                  ChoiceChip(
                    label: Text(formatDuration(m)),
                    selected: selectedDuration == m,
                    onSelected: (_) => _duration.text = '$m',
                  ),
              ],
            ),
          ],
          AppSpacing.gapLg,
          AppTextField(
            key: const Key('service-description'),
            label: 'Description (optional)',
            controller: _description,
            enabled: enabled,
            maxLines: 3,
            errorText: _serverErrors['description'],
          ),
          if (!widget.readOnly) ...[
            AppSpacing.gapXl,
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                key: const Key('service-submit'),
                label: widget.submitLabel,
                onPressed: _submit,
                loading: _busy,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

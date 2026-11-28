import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_radius.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_pill.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/scroll_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../../staff/presentation/staff_section_tabs.dart';
import '../application/compensation_providers.dart';
import '../domain/pay.dart';

/// Staff & pay → Commission & salary.
/// Top: the salon default %. Left: employees. Right: the chosen employee's
/// monthly salary and their own % for every service and product.
class PaySetupScreen extends ConsumerWidget {
  const PaySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(paySummariesProvider);
    final selected = ref.watch(selectedPayStaffProvider);
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.compensationManage) ?? false));
    final compact = context.layoutSize == LayoutSize.compact;

    return PageScaffold(
      subtitle: 'Staff & pay',
      title: 'Commission & salary',
      body: summaries.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Could not load employees.',
          onRetry: () => ref.invalidate(paySummariesProvider),
        ),
        data: (list) {
          if (list.isEmpty) return const EmptyView(message: 'No active employees yet. Add employees first.');
          final staffId = selected ?? list.first.staffId;
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StaffSectionTabs(current: StaffSection.pay),
              AppSpacing.gapLg,
              _SalonDefaultCard(canManage: canManage),
              AppSpacing.gapLg,
            ],
          );
          if (compact) {
            return ScrollBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  AppDropdown<PaySummary>(
                    key: const Key('pay-employee-picker'),
                    label: 'Employee',
                    items: list,
                    itemLabel: (s) => s.fullName,
                    value: list.where((s) => s.staffId == staffId).firstOrNull,
                    onChanged: (s) {
                      if (s != null) ref.read(selectedPayStaffProvider.notifier).select(s.staffId);
                    },
                  ),
                  AppSpacing.gapLg,
                  _PayEditor(staffId: staffId, canManage: canManage),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: AppSizes.sidebarExpandedWidth + AppSpacing.xxl,
                      child: _EmployeeList(items: list, selectedId: staffId),
                    ),
                    AppSpacing.gapLg,
                    Expanded(
                      child: ScrollBody(
                        child: _PayEditor(staffId: staffId, canManage: canManage),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SalonDefaultCard extends ConsumerStatefulWidget {
  const _SalonDefaultCard({required this.canManage});

  final bool canManage;

  @override
  ConsumerState<_SalonDefaultCard> createState() => _SalonDefaultCardState();
}

class _SalonDefaultCardState extends ConsumerState<_SalonDefaultCard> {
  final _formKey = GlobalKey<FormState>();
  final _pct = TextEditingController();
  String? _loaded;
  bool _busy = false;

  @override
  void dispose() {
    _pct.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(compensationApiProvider).setSalonDefault(_pct.text.trim());
      ref
        ..invalidate(salonDefaultProvider)
        ..invalidate(staffPayProvider);
      if (mounted) showAppMessage(context, 'Salon default saved');
    } on ApiException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(salonDefaultProvider).value;
    if (value != null && value != _loaded) {
      _loaded = value;
      _pct.text = formatPercent(value).replaceAll('%', '');
    }
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return AppCard(
      child: Form(
        key: _formKey,
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salon default commission', style: theme.textTheme.titleMedium),
                  Text(
                    'Used for employees without a monthly salary, on any service or product they have no own rate for.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: AppSizes.statTileMinWidth * 0.6,
              child: AppTextField(
                key: const Key('salon-default'),
                label: 'Default %',
                controller: _pct,
                enabled: widget.canManage && !_busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => Validators.required(v, 'Enter a %') ?? Validators.percent(v),
              ),
            ),
            if (widget.canManage)
              AppButton(
                key: const Key('salon-default-save'),
                label: 'Save default',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                loading: _busy,
                onPressed: _save,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeList extends ConsumerWidget {
  const _EmployeeList({required this.items, required this.selectedId});

  final List<PaySummary> items;
  final int selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => AppSpacing.gapXs,
        itemBuilder: (context, i) {
          final s = items[i];
          final selected = s.staffId == selectedId;
          final pay = s.monthlySalary == null ? 'Commission' : 'Salary ${formatMoney(s.monthlySalary)}';
          return Material(
            color: selected ? colors.selectedItem : Colors.transparent,
            borderRadius: AppRadius.button,
            child: InkWell(
              key: Key('pay-employee-${s.staffId}'),
              borderRadius: AppRadius.button,
              overlayColor: colors.overlay,
              onTap: () => ref.read(selectedPayStaffProvider.notifier).select(s.staffId),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.fullName,
                      style: theme.textTheme.titleSmall?.copyWith(color: selected ? colors.selectedIcon : null),
                    ),
                    Text(
                      [
                        pay,
                        if (s.specificRates > 0) '${s.specificRates} own rate${s.specificRates == 1 ? '' : 's'}',
                        if (!s.performsServices) 'front desk',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PayEditor extends ConsumerWidget {
  const _PayEditor({required this.staffId, required this.canManage});

  final int staffId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(staffPayProvider(staffId))
        .when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingView()),
          error: (e, _) => ErrorView(
            message: e is ApiException ? e.message : 'Could not load pay.',
            onRetry: () => ref.invalidate(staffPayProvider(staffId)),
          ),
          // A new key per loaded version resets the fields to what was saved.
          data: (pay) => _PayForm(key: ValueKey(pay), pay: pay, canManage: canManage),
        );
  }
}

class _PayForm extends ConsumerStatefulWidget {
  const _PayForm({super.key, required this.pay, required this.canManage});

  final StaffPay pay;
  final bool canManage;

  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  final _formKey = GlobalKey<FormState>();
  late final _salary = TextEditingController(text: _plain(widget.pay.monthlySalary));
  late final Map<String, TextEditingController> _rates = {
    for (final i in [...widget.pay.services, ...widget.pay.products])
      i.key: TextEditingController(text: _plain(i.ratePct)),
  };
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_salary, ..._rates.values]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_salary, ..._rates.values]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _plain(String? v) {
    if (v == null) return '';
    final d = double.tryParse(v);
    if (d == null) return v;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  static bool _same(String a, String b) =>
      (a.trim().isEmpty && b.trim().isEmpty) || (double.tryParse(a.trim()) ?? -1) == (double.tryParse(b.trim()) ?? -2);

  Iterable<PayItem> get _items => [...widget.pay.services, ...widget.pay.products];

  List<RateChange> get _changes => [
    for (final i in _items)
      if (!_same(_rates[i.key]!.text, _plain(i.ratePct)))
        RateChange(i.type, i.itemId, _rates[i.key]!.text.trim().isEmpty ? null : _rates[i.key]!.text.trim()),
  ];

  bool get _salaryChanged => !_same(_salary.text, _plain(widget.pay.monthlySalary));
  bool get _dirty => _salaryChanged || _changes.isNotEmpty;

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(compensationApiProvider)
          .save(
            widget.pay.staffId,
            monthlySalary: _salary.text.trim().isEmpty ? null : _salary.text.trim(),
            rates: _changes,
          );
      ref
        ..invalidate(staffPayProvider(widget.pay.staffId))
        ..invalidate(paySummariesProvider);
      if (mounted) showAppMessage(context, 'Pay for ${widget.pay.fullName} saved');
    } on ApiException catch (e) {
      if (mounted) showAppMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final pay = widget.pay;
    final hasSalary = _salary.text.trim().isNotEmpty;
    final enabled = widget.canManage && !_busy;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pay.fullName, style: theme.textTheme.headlineSmall),
                          Text(pay.roleName, style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    if (widget.canManage)
                      AppButton(
                        key: const Key('pay-save'),
                        label: _dirty ? 'Save changes' : 'Saved',
                        loading: _busy,
                        onPressed: _dirty ? _save : null,
                      ),
                  ],
                ),
                AppSpacing.gapLg,
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: AppSizes.formMaxWidth * 0.55,
                      child: AppTextField(
                        key: const Key('pay-salary'),
                        label: 'Monthly salary (₹)',
                        hint: 'Leave blank if commission only',
                        controller: _salary,
                        enabled: enabled,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => Validators.money(v, positive: true, optional: true),
                      ),
                    ),
                    AppPill(
                      label: hasSalary ? 'Salaried' : 'Commission-based',
                      color: hasSalary ? colors.info : colors.success,
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                Text(
                  hasSalary
                      ? 'Earns commission only on items with their own % below.'
                      : 'Items without their own % earn the salon default (${formatPercent(pay.salonDefaultPct)}).',
                  key: const Key('pay-rule'),
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          _RatesCard(
            title: 'Services',
            emptyText: 'No active services yet. Add them under Services.',
            items: pay.services,
            rates: _rates,
            hasSalary: hasSalary,
            salonDefaultPct: pay.salonDefaultPct,
            enabled: enabled,
          ),
          AppSpacing.gapLg,
          _RatesCard(
            title: 'Products',
            emptyText: 'No active products yet. Add them under Inventory.',
            items: pay.products,
            rates: _rates,
            hasSalary: hasSalary,
            salonDefaultPct: pay.salonDefaultPct,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.rates,
    required this.hasSalary,
    required this.salonDefaultPct,
    required this.enabled,
  });

  final String title;
  final String emptyText;
  final List<PayItem> items;
  final Map<String, TextEditingController> rates;
  final bool hasSalary;
  final String salonDefaultPct;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    // What applies when the field is blank, given the salary as currently typed.
    final blankMeans = hasSalary ? 'No commission' : 'Default ${formatPercent(salonDefaultPct)}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          AppSpacing.gapXs,
          Text('Leave a % blank to use: $blankMeans.', style: muted),
          AppSpacing.gapMd,
          if (items.isEmpty) Text(emptyText, style: muted),
          for (final item in items) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text([if (item.detail != null) item.detail!, formatMoney(item.price)].join(' · '), style: muted),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
                SizedBox(
                  width: AppSizes.buttonMinWidth + AppSpacing.lg,
                  child: AppTextField(
                    key: Key('rate-${item.key}'),
                    label: '%',
                    hint: rates[item.key]!.text.isEmpty ? (hasSalary ? '—' : formatPercent(salonDefaultPct)) : null,
                    controller: rates[item.key],
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: Validators.percent,
                  ),
                ),
                AppSpacing.gapMd,
                SizedBox(
                  width: AppSizes.statTileMinWidth * 0.6,
                  child: Text(
                    rates[item.key]!.text.trim().isNotEmpty ? 'Own rate' : blankMeans,
                    key: Key('rate-note-${item.key}'),
                    style: muted?.copyWith(
                      color: rates[item.key]!.text.trim().isNotEmpty
                          ? colors.selectedIcon
                          : hasSalary
                          ? colors.disabledText
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
          ],
          if (items.isNotEmpty && !enabled)
            Row(
              children: [
                Icon(AppIcons.password, size: AppSizes.iconSm, color: colors.disabledText),
                AppSpacing.gapXs,
                Text('View only', style: muted),
              ],
            ),
        ],
      ),
    );
  }
}

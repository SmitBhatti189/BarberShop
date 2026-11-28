import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/staff_providers.dart';
import '../domain/employee.dart';

/// Optional sign-in details entered with a new employee.
class LoginDraft {
  const LoginDraft(this.username, this.password);
  final String username;
  final String password;
}

/// Returns server field errors to show, or null on success.
typedef EmployeeSubmit = Future<Map<String, String>?> Function(EmployeeDraft draft, LoginDraft? login);

/// Employee details form, shared by "Add employee" and the edit screen.
/// Checks the obvious mistakes before sending; the server re-checks everything
/// and its field errors are shown under the matching field.
class EmployeeForm extends ConsumerStatefulWidget {
  const EmployeeForm({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.initial,
    this.includeLogin = false,
    this.readOnly = false,
  });

  final Employee? initial;
  final EmployeeSubmit onSubmit;
  final String submitLabel;

  /// New employees can be given a login in the same step.
  final bool includeLogin;

  /// For people who may view but not change employees.
  final bool readOnly;

  @override
  ConsumerState<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.fullName);
  late final _mobile = TextEditingController(text: widget.initial?.mobile);
  late final _email = TextEditingController(text: widget.initial?.email);
  late final _joined = TextEditingController(text: _displayDate(widget.initial?.joinedOn));
  final _username = TextEditingController();
  final _password = TextEditingController();
  late String? _joinedOn = widget.initial?.joinedOn;
  late int? _roleId = widget.initial?.roleId;
  late bool _performsServices = widget.initial?.performsServices ?? true;
  bool _canSignIn = false;
  bool _busy = false;
  Map<String, String> _serverErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _joined, _username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _displayDate(String? iso) => iso == null ? '' : DateFormat('d MMM y').format(DateTime.parse(iso));

  static String? _mobileError(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
    if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? null : 'Enter a 10-digit mobile number';
  }

  static String? _emailError(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value) ? null : 'Enter a valid email address';
  }

  Future<void> _pickJoinDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinedOn == null ? now : DateTime.parse(_joinedOn!),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
      helpText: 'Joined on',
    );
    if (picked == null) return;
    setState(() {
      _joinedOn = DateFormat('yyyy-MM-dd').format(picked);
      _joined.text = _displayDate(_joinedOn);
    });
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _serverErrors = const {};
    });
    String? orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final errors = await widget.onSubmit(
      EmployeeDraft(
        fullName: _name.text.trim(),
        mobile: orNull(_mobile),
        email: orNull(_email),
        roleId: _roleId!,
        performsServices: _performsServices,
        joinedOn: _joinedOn,
      ),
      widget.includeLogin && _canSignIn ? LoginDraft(_username.text.trim(), _password.text) : null,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _serverErrors = errors ?? const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider);
    final enabled = !widget.readOnly && !_busy;
    final colors = AppColors.of(context);

    final details = <Widget>[
      AppTextField(
        key: const Key('employee-name'),
        label: 'Full name',
        prefixIcon: AppIcons.user,
        controller: _name,
        enabled: enabled,
        errorText: _serverErrors['fullName'],
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
      ),
      AppSpacing.gapLg,
      AppTextField(
        key: const Key('employee-mobile'),
        label: 'Mobile (optional)',
        hint: '98765 43210',
        prefixIcon: AppIcons.phone,
        controller: _mobile,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        errorText: _serverErrors['mobile'],
        validator: _mobileError,
      ),
      AppSpacing.gapLg,
      AppTextField(
        key: const Key('employee-email'),
        label: 'Email (optional)',
        prefixIcon: AppIcons.email,
        controller: _email,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        errorText: _serverErrors['email'],
        validator: _emailError,
      ),
      AppSpacing.gapLg,
      roles.when(
        data: (list) => AppDropdown<RoleOption>(
          key: const Key('employee-role'),
          label: 'Role',
          items: list,
          itemLabel: (r) => r.name,
          value: list.where((r) => r.id == _roleId).firstOrNull,
          enabled: enabled,
          onChanged: (r) => setState(() => _roleId = r?.id),
          validator: (r) => r == null ? 'Choose a role' : _serverErrors['roleId'],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Could not load roles. $e', style: TextStyle(color: colors.error)),
      ),
      AppSpacing.gapLg,
      AppTextField(
        label: 'Joined on (optional)',
        prefixIcon: AppIcons.calendar,
        controller: _joined,
        enabled: enabled,
        readOnly: true,
        onTap: _pickJoinDate,
        errorText: _serverErrors['joinedOn'],
      ),
      AppSpacing.gapSm,
      SwitchListTile(
        key: const Key('employee-performs-services'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Performs services'),
        subtitle: const Text('Can be booked for haircuts and other services'),
        value: _performsServices,
        onChanged: enabled ? (v) => setState(() => _performsServices = v) : null,
      ),
    ];

    final submit = Align(
      alignment: Alignment.centerLeft,
      child: AppButton(
        key: const Key('employee-submit'),
        label: widget.submitLabel,
        onPressed: _submit,
        loading: _busy,
      ),
    );

    // Edit screen: details only, inside the caller's card.
    if (!widget.includeLogin) {
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

    final signIn = <Widget>[
      SwitchListTile(
        key: const Key('employee-can-sign-in'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Can sign in to the app'),
        subtitle: const Text('Optional. Employees without a login are still paid and can be booked.'),
        value: _canSignIn,
        onChanged: enabled ? (v) => setState(() => _canSignIn = v) : null,
      ),
      if (_canSignIn) ...[
        AppSpacing.gapSm,
        AppTextField(
          key: const Key('employee-username'),
          label: 'Username',
          prefixIcon: AppIcons.user,
          controller: _username,
          enabled: enabled,
          errorText: _serverErrors['username'],
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.length < 3) return 'At least 3 characters';
            if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) return 'Use letters, numbers, dot, dash or underscore';
            return null;
          },
        ),
        AppSpacing.gapLg,
        AppTextField(
          key: const Key('employee-password'),
          label: 'Password',
          prefixIcon: AppIcons.password,
          controller: _password,
          obscure: true,
          enabled: enabled,
          errorText: _serverErrors['password'],
          validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
        ),
      ],
    ];

    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final detailsCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Details', style: titleStyle),
          AppSpacing.gapLg,
          ...details,
        ],
      ),
    );
    // The save button sits under the sign-in part, so on wide screens the
    // whole form fits without scrolling.
    final signInCard = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign-in', style: titleStyle),
          ...signIn,
          if (!widget.readOnly) ...[AppSpacing.gapXl, submit],
        ],
      ),
    );

    // New employee: details on the left, sign-in on the right when there is
    // room; stacked on phones and narrow windows.
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= AppSizes.employeeFormTwoColumnMin
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: detailsCard),
                  AppSpacing.gapLg,
                  Expanded(child: signInCard),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [detailsCard, AppSpacing.gapLg, signInCard],
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/scroll_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/staff_providers.dart';
import '../domain/employee.dart';
import 'employee_form.dart';
import 'staff_list_screen.dart' show StatusPill;
import 'staff_routes.dart';

/// One employee: edit details, manage their login, deactivate or reactivate.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(employeeProvider(id));
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.staffManage) ?? false));

    return PageScaffold(
      subtitle: 'Staff & pay · Employees',
      title: employee.value?.fullName ?? 'Employee',
      actions: [
        AppButton(
          label: 'Back',
          icon: AppIcons.back,
          variant: AppButtonVariant.text,
          onPressed: () => context.go(StaffRoutes.list),
        ),
      ],
      body: employee.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Could not load this employee.',
          onRetry: () => ref.invalidate(employeeProvider(id)),
        ),
        data: (e) => _Body(employee: e, canManage: canManage),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.employee, required this.canManage});

  final Employee employee;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Details', style: Theme.of(context).textTheme.titleMedium)),
              StatusPill(active: employee.isActive),
            ],
          ),
          AppSpacing.gapLg,
          EmployeeForm(
            // A new key after each save reloads the form from the saved values.
            key: ValueKey('form-${employee.id}-${employee.version}'),
            initial: employee,
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
        _SignInCard(employee: employee, canManage: canManage),
        AppSpacing.gapLg,
        if (canManage) _StatusCard(employee: employee),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= AppSizes.dashboardTwoColumnMin;
        return ScrollBody(
          child: twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    AppSpacing.gapLg,
                    SizedBox(width: AppSizes.dashboardSideWidth, child: side),
                  ],
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, AppSpacing.gapLg, side]),
        );
      },
    );
  }

  Future<Map<String, String>?> _save(BuildContext context, WidgetRef ref, EmployeeDraft draft) async {
    try {
      await ref.read(staffApiProvider).update(employee.id, employee.version, draft);
      ref.invalidate(employeeProvider(employee.id));
      ref.invalidate(staffListProvider);
      if (context.mounted) showAppMessage(context, 'Changes saved');
      return null;
    } on ApiException catch (e) {
      if (e.code == 'STALE') ref.invalidate(employeeProvider(employee.id));
      final fields = formFieldErrors(e);
      if (fields.isEmpty && context.mounted) showAppMessage(context, e.message, error: true);
      return fields;
    }
  }
}

class _SignInCard extends ConsumerWidget {
  const _SignInCard({required this.employee, required this.canManage});

  final Employee employee;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final e = employee;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign-in', style: theme.textTheme.titleMedium),
          AppSpacing.gapSm,
          Row(
            children: [
              Icon(
                e.canSignIn ? AppIcons.login : AppIcons.noLogin,
                size: AppSizes.iconMd,
                color: colors.unselectedIcon,
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  e.canSignIn ? 'Signs in as ${e.username}' : 'No login. Can still be booked and paid.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (canManage) ...[
            AppSpacing.gapLg,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  key: const Key('set-login'),
                  label: e.canSignIn ? 'Change password' : 'Give a login',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _editLogin(context, ref),
                ),
                if (e.canSignIn)
                  AppButton(
                    key: const Key('remove-login'),
                    label: 'Remove login',
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.small,
                    onPressed: () => _removeLogin(context, ref),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editLogin(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LoginDialog(employee: employee),
    );
    if (saved != true) return;
    ref
      ..invalidate(employeeProvider(employee.id))
      ..invalidate(staffListProvider);
  }

  Future<void> _removeLogin(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove login?',
      message: '${employee.fullName} will be signed out and won\'t be able to sign in. Their record and pay stay.',
      confirmLabel: 'Remove login',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(context, ref, () => ref.read(staffApiProvider).removeLogin(employee.id), 'Login removed');
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = employee.isActive;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(active ? 'Deactivate' : 'Reactivate', style: theme.textTheme.titleMedium),
          AppSpacing.gapSm,
          Text(
            active
                ? 'For someone who has left. They are signed out and hidden from bookings; their history and pay records stay.'
                : 'Bring this employee back. If they had a login, they can sign in again.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.of(context).textSecondary),
          ),
          AppSpacing.gapLg,
          AppButton(
            key: const Key('toggle-active'),
            label: active ? 'Deactivate employee' : 'Reactivate employee',
            icon: active ? AppIcons.deactivate : AppIcons.activate,
            variant: active ? AppButtonVariant.danger : AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () async {
              if (active) {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Deactivate ${employee.fullName}?',
                  message:
                      'They will be signed out on every device and can\'t be booked. You can reactivate them later.',
                  confirmLabel: 'Deactivate',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
              }
              await _run(
                context,
                ref,
                () => ref.read(staffApiProvider).setActive(employee.id, !active),
                active ? '${employee.fullName} deactivated' : '${employee.fullName} reactivated',
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Runs one change, then refreshes the employee or shows the server's reason.
Future<void> _run(BuildContext context, WidgetRef ref, Future<Employee> Function() action, String success) async {
  try {
    final updated = await action();
    ref.invalidate(employeeProvider(updated.id));
    ref.invalidate(staffListProvider);
    if (context.mounted) showAppMessage(context, success);
  } on ApiException catch (e) {
    if (context.mounted) showAppMessage(context, e.message, error: true);
  }
}

class _LoginDialog extends ConsumerStatefulWidget {
  const _LoginDialog({required this.employee});

  final Employee employee;

  @override
  ConsumerState<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<_LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.employee.username);
  final _password = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _message; // shown inside the dialog

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _errors = const {};
    });
    try {
      await ref.read(staffApiProvider).setLogin(widget.employee.id, _username.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showAppMessage(context, 'Login saved. ${widget.employee.fullName} must use the new password.');
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
    final hasLogin = widget.employee.canSignIn;
    return AppDialog(
      error: _message,
      title: hasLogin ? 'Change password' : 'Give ${widget.employee.fullName} a login',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              key: const Key('login-username'),
              label: 'Username',
              prefixIcon: AppIcons.user,
              controller: _username,
              errorText: _errors['username'],
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.length < 3) return 'At least 3 characters';
                if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) {
                  return 'Use letters, numbers, dot, dash or underscore';
                }
                return null;
              },
            ),
            AppSpacing.gapLg,
            AppTextField(
              key: const Key('login-password'),
              label: hasLogin ? 'New password' : 'Password',
              prefixIcon: AppIcons.password,
              controller: _password,
              obscure: true,
              errorText: _errors['password'],
              validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
            ),
            if (hasLogin) ...[
              AppSpacing.gapSm,
              Text(
                'They will be signed out on their other devices.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.of(context).textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(label: 'Cancel', variant: AppButtonVariant.text, onPressed: () => Navigator.of(context).pop(false)),
        AppButton(key: const Key('login-save'), label: 'Save login', loading: _busy, onPressed: _save),
      ],
    );
  }
}

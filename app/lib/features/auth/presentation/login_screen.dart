import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_radius.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/providers.dart';
import '../../../core/server/server_address.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'auth_form_frame.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  static String? required(String? value, String field) =>
      (value == null || value.trim().isEmpty) ? 'Enter your $field' : null;

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(authControllerProvider.notifier).login(_username.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final notice = auth is AuthSignedOut ? auth.message : null;
    final message = _error ?? notice;
    final canChangeServer = ref.watch(appEnvProvider).allowServerOverride;

    return AuthFormFrame(
      title: 'Welcome back',
      subtitle: 'Sign in with your staff username.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Username',
                prefixIcon: AppIcons.user,
                controller: _username,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => required(v, 'username'),
              ),
              AppSpacing.gapLg,
              AppTextField(
                label: 'Password',
                prefixIcon: AppIcons.password,
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) => required(v, 'password'),
                onSubmitted: (_) => _submit(),
              ),
              if (message != null) ...[
                AppSpacing.gapMd,
                Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              AppSpacing.gapXl,
              AppButton(label: 'Sign in', onPressed: _submit, loading: _busy, expand: true),
              if (canChangeServer) ...[
                AppSpacing.gapLg,
                _ServerLine(
                  address: displayServerAddress(ref.watch(apiClientProvider).baseUrl),
                  onChange: _busy ? null : () => ref.read(authControllerProvider.notifier).changeServer(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Server 192.168.1.10:8080 · Change server" under the sign-in button.
class _ServerLine extends StatelessWidget {
  const _ServerLine({required this.address, required this.onChange});

  final String? address;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.button,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Icon(AppIcons.server, size: AppSizes.iconSm, color: colors.textSecondary),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              address == null ? 'No server set' : 'Server $address',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          AppButton(
            label: 'Change server',
            variant: AppButtonVariant.text,
            size: AppButtonSize.small,
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}

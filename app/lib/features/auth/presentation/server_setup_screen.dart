import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'auth_form_frame.dart';

/// First-launch screen (dev builds): where is the salon's server?
/// The address is verified with GET /health before it is saved.
class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _address = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(authControllerProvider.notifier).setServer(_address.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormFrame(
      icon: AppIcons.server,
      title: 'Connect to the salon server',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Server address',
            hint: '192.168.1.10:8080',
            prefixIcon: AppIcons.server,
            controller: _address,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autofocus: true,
            errorText: _error,
            onSubmitted: (_) => _connect(),
          ),
          AppSpacing.gapSm,
          Text(
            'Use the IP address of the PC running the server. This device must be on the same Wi-Fi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppSpacing.gapXl,
          AppButton(label: 'Connect', onPressed: _connect, loading: _busy, expand: true),
        ],
      ),
    );
  }
}

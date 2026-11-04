import 'package:flutter/material.dart';

import '../../config/app_strings.dart';
import '../../config/assets/app_icons.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import 'app_button.dart';

/// Centered spinner for whole-area loading.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[AppSpacing.gapLg, Text(message!)],
        ],
      ),
    );
  }
}

/// Error with an optional retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: AppIcons.error,
      iconColor: Theme.of(context).colorScheme.error,
      message: message,
      action: onRetry == null
          ? null
          : AppButton(
              label: AppStrings.retry,
              icon: AppIcons.retry,
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
    );
  }
}

/// "Nothing here yet" state for lists.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: AppIcons.empty,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      message: message,
      action: action,
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.iconColor, required this.message, this.action});

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconXl, color: iconColor),
            AppSpacing.gapMd,
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[AppSpacing.gapLg, action!],
          ],
        ),
      ),
    );
  }
}

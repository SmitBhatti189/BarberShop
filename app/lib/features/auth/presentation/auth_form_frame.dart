import 'package:flutter/material.dart';

import '../../../config/app_strings.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/router/app_brand.dart';

/// Layout shared by the server-setup and login screens.
/// * Wide windows: dark brand panel on the left, the form on the right.
/// * Narrow windows / phones: logo and salon name above the form.
class AuthFormFrame extends StatelessWidget {
  const AuthFormFrame({super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppSizes.authWideMin;
    final form = _Form(title: title, subtitle: subtitle, showBrand: !wide, child: child);
    return Scaffold(
      body: wide
          ? Row(
              children: [
                const SizedBox(width: AppSizes.authPanelWidth, child: _BrandPanel()),
                Expanded(child: form),
              ],
            )
          : form,
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.title, required this.subtitle, required this.showBrand, required this.child});

  final String title;
  final String subtitle;
  final bool showBrand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.authFormMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBrand) ...[
                  const Align(alignment: Alignment.centerLeft, child: AppBrand()),
                  AppSpacing.gapXxl,
                ],
                Text(title, style: theme.textTheme.displaySmall),
                AppSpacing.gapSm,
                Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                AppSpacing.gapXl,
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Charcoal panel with the logo and the salon's one-line promise.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: colors.sidebarBackground,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppBrand(onDark: true, markSize: AppSizes.brandMarkLarge),
            const Spacer(),
            Text(AppStrings.tagline, style: textTheme.displayMedium?.copyWith(color: colors.sidebarTextStrong)),
            AppSpacing.gapLg,
            Text(AppStrings.taglineDetail, style: textTheme.bodyLarge?.copyWith(color: colors.sidebarText)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

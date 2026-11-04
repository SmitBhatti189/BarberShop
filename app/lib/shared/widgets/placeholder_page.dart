import 'package:flutter/material.dart';

import '../../config/app_strings.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import 'page_scaffold.dart';

/// Stand-in for a module that has not been implemented yet. It states that
/// plainly, so an unfinished feature is never mistaken for a working one.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageScaffold(
      title: title,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconXl, color: theme.colorScheme.onSurfaceVariant),
            AppSpacing.gapMd,
            Text(AppStrings.notImplemented, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

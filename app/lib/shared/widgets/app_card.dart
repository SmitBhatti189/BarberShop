import 'package:flutter/material.dart';

import '../../config/theme/app_radius.dart';
import '../../config/theme/app_spacing.dart';

/// Outlined content card; tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(AppSpacing.lg)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

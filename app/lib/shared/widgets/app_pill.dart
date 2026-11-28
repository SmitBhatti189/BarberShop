import 'package:flutter/material.dart';

import '../../config/theme/app_radius.dart';
import '../../config/theme/app_spacing.dart';

/// Small rounded status label ("Active", "Low stock", …) tinted with [color].
class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: AppRadius.chip),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

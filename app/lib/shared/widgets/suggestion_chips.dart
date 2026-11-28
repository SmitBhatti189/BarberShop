import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_spacing.dart';

/// One-tap suggestions from names already used, filtered by what's typed.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({super.key, required this.options, required this.controller});

  final List<String> options;
  final TextEditingController controller;

  static const _max = 6;

  @override
  Widget build(BuildContext context) {
    final typed = controller.text.trim().toLowerCase();
    final matches = options
        .where((o) => o.toLowerCase() != typed && (typed.isEmpty || o.toLowerCase().contains(typed)))
        .take(_max)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final o in matches)
            ActionChip(
              label: Text(o),
              backgroundColor: colors.secondaryButton,
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.secondaryText),
              side: BorderSide.none,
              onPressed: () => controller.text = o,
            ),
        ],
      ),
    );
  }
}

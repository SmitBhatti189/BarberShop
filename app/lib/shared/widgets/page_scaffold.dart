import 'package:flutter/material.dart';

import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import '../../core/responsive/breakpoints.dart';

/// Standard page inside the shell: page title + optional actions, responsive
/// padding, and a max content width on large screens. (The app-wide navbar
/// sits above it, so pages have no AppBar of their own.)
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.floatingAction,
  });

  final String title;

  /// Small line above the title (e.g. today's date).
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.layoutSize == LayoutSize.compact;
    final padding = compact ? AppSpacing.pagePaddingCompact : AppSpacing.pagePaddingExpanded;
    return Scaffold(
      floatingActionButton: floatingAction,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          Text(title, style: compact ? theme.textTheme.headlineMedium : theme.textTheme.displaySmall),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
                AppSpacing.gapXl,
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

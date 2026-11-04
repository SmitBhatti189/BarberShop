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
    this.actions = const [],
    this.floatingAction,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final padding = context.layoutSize == LayoutSize.compact
        ? AppSpacing.pagePaddingCompact
        : AppSpacing.pagePaddingExpanded;
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
                  children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
                    ...actions,
                  ],
                ),
                AppSpacing.gapLg,
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

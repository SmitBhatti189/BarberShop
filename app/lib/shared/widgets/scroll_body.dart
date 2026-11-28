import 'package:flutter/material.dart';

import '../../config/theme/app_spacing.dart';

/// Scrollable page content with a scrollbar that is always visible on
/// desktop/web, so long forms are obviously scrollable on short windows.
/// Owns (and disposes) its own controller.
class ScrollBody extends StatefulWidget {
  const ScrollBody({super.key, required this.child});

  final Widget child;

  @override
  State<ScrollBody> createState() => _ScrollBodyState();
}

class _ScrollBodyState extends State<ScrollBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        // Leaves room so the scrollbar never covers the content.
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: widget.child,
      ),
    );
  }
}

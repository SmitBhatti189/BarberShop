import 'package:flutter/material.dart';

/// Shows [message] as a hover tooltip only when [enabled] — pass one of the
/// switches from `AppHoverLabels` so hover labels are controlled centrally.
class HoverLabel extends StatelessWidget {
  const HoverLabel({super.key, required this.enabled, required this.message, required this.child});

  final bool enabled;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled ? Tooltip(message: message, child: child) : child;
}

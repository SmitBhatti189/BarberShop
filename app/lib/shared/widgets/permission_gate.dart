import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';

/// Renders [child] only if the signed-in user has ANY of [anyOf].
/// UI convenience only — the backend enforces every permission itself.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key, required this.anyOf, required this.child, this.fallback = const SizedBox.shrink()});

  final List<String> anyOf;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` limits rebuilds to changes in this one answer.
    final allowed = ref.watch(currentUserProvider.select((u) => u != null && u.canAny(anyOf)));
    return allowed ? child : fallback;
  }
}

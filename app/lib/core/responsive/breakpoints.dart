import 'package:flutter/widgets.dart';

import '../../config/theme/app_sizes.dart';

/// Layout classes, decided only by available width (works for phones,
/// tablets and resizable desktop windows alike).
enum LayoutSize { compact, medium, expanded }

LayoutSize layoutSizeForWidth(double width) {
  if (width < AppSizes.compactMax) return LayoutSize.compact;
  if (width < AppSizes.mediumMax) return LayoutSize.medium;
  return LayoutSize.expanded;
}

extension LayoutSizeContext on BuildContext {
  /// Uses `MediaQuery.sizeOf`, which only rebuilds on size changes (not on
  /// keyboard/insets changes), keeping rebuilds minimal.
  LayoutSize get layoutSize => layoutSizeForWidth(MediaQuery.sizeOf(this).width);
}

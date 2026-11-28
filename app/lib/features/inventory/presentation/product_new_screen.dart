import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/scroll_body.dart';
import '../application/inventory_providers.dart';
import 'inventory_routes.dart';
import 'product_form.dart';

class ProductNewScreen extends ConsumerWidget {
  const ProductNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      subtitle: 'Inventory',
      title: 'Add product',
      actions: [
        AppButton(
          label: 'Back',
          icon: AppIcons.back,
          variant: AppButtonVariant.text,
          onPressed: () => context.go(InventoryRoutes.list),
        ),
      ],
      body: ScrollBody(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.employeeFormMaxWidth),
            child: ProductForm(
              includeOpeningStock: true,
              submitLabel: 'Add product',
              onSubmit: (draft, openingStock) async {
                try {
                  final created = await ref.read(inventoryApiProvider).create(draft, openingStock: openingStock);
                  ref.invalidate(productSuggestionsProvider);
                  ref.invalidate(inventoryListProvider);
                  if (!context.mounted) return null;
                  showAppMessage(context, '${created.name} added');
                  context.go(InventoryRoutes.product(created.id));
                  return null;
                } on ApiException catch (e) {
                  final fields = formFieldErrors(e);
                  if (fields.isEmpty && context.mounted) showAppMessage(context, e.message, error: true);
                  return fields;
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

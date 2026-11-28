import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/scroll_body.dart';
import '../application/services_providers.dart';
import 'service_form.dart';
import 'services_routes.dart';

class ServiceNewScreen extends ConsumerWidget {
  const ServiceNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      subtitle: 'Services',
      title: 'Add service',
      actions: [
        AppButton(
          label: 'Back',
          icon: AppIcons.back,
          variant: AppButtonVariant.text,
          onPressed: () => context.go(ServicesRoutes.list),
        ),
      ],
      body: ScrollBody(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth + AppSizes.dashboardSideWidth / 2),
            child: AppCard(
              child: ServiceForm(
                submitLabel: 'Add service',
                onSubmit: (draft) async {
                  try {
                    final created = await ref.read(servicesApiProvider).create(draft);
                    ref.invalidate(serviceCategoriesProvider);
                    ref.invalidate(servicesListProvider);
                    if (!context.mounted) return null;
                    showAppMessage(context, '${created.name} added');
                    context.go(ServicesRoutes.list);
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
      ),
    );
  }
}

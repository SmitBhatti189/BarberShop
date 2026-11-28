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
import '../application/staff_providers.dart';
import 'employee_form.dart';
import 'staff_routes.dart';

class EmployeeNewScreen extends ConsumerWidget {
  const EmployeeNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      subtitle: 'Staff & pay',
      title: 'Add employee',
      actions: [
        AppButton(
          label: 'Back',
          icon: AppIcons.back,
          variant: AppButtonVariant.text,
          onPressed: () => context.go(StaffRoutes.list),
        ),
      ],
      body: ScrollBody(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.employeeFormMaxWidth),
            child: EmployeeForm(
              includeLogin: true,
              submitLabel: 'Add employee',
              onSubmit: (draft, login) async {
                try {
                  final created = await ref
                      .read(staffApiProvider)
                      .create(draft, username: login?.username, password: login?.password);
                  // The list stays mounted under this page, so refresh it.
                  ref.invalidate(staffListProvider);
                  if (!context.mounted) return null;
                  showAppMessage(context, '${created.fullName} added');
                  context.go(StaffRoutes.employee(created.id));
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

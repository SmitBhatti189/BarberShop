import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/assets/app_icons.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_sizes.dart';
import '../../../config/theme/app_spacing.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_pill.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/scroll_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/services_providers.dart';
import '../domain/salon_service.dart';
import 'service_form.dart';
import 'services_routes.dart';

/// One service: edit name, price, duration; stop or resume offering it.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(serviceProvider(id));
    final canManage = ref.watch(currentUserProvider.select((u) => u?.can(Permissions.servicesManage) ?? false));
    return PageScaffold(
      subtitle: 'Services',
      title: service.value?.name ?? 'Service',
      actions: [
        AppButton(
          label: 'Back',
          icon: AppIcons.back,
          variant: AppButtonVariant.text,
          onPressed: () => context.go(ServicesRoutes.list),
        ),
      ],
      body: service.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Could not load this service.',
          onRetry: () => ref.invalidate(serviceProvider(id)),
        ),
        data: (s) => _Body(service: s, canManage: canManage),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.service, required this.canManage});

  final SalonService service;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final details = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Service', style: Theme.of(context).textTheme.titleMedium)),
              AppPill(
                label: service.isActive ? 'Offered' : 'Not offered',
                color: service.isActive ? colors.success : colors.disabledText,
              ),
            ],
          ),
          AppSpacing.gapLg,
          ServiceForm(
            key: ValueKey('service-form-${service.id}-${service.version}'),
            initial: service,
            readOnly: !canManage,
            submitLabel: 'Save changes',
            onSubmit: (draft) => _save(context, ref, draft),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= AppSizes.dashboardTwoColumnMin;
        final side = canManage ? _StatusCard(service: service) : null;
        return ScrollBody(
          child: twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    if (side != null) ...[AppSpacing.gapLg, SizedBox(width: AppSizes.dashboardSideWidth, child: side)],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    if (side != null) ...[AppSpacing.gapLg, side],
                  ],
                ),
        );
      },
    );
  }

  Future<Map<String, String>?> _save(BuildContext context, WidgetRef ref, ServiceDraft draft) async {
    try {
      await ref.read(servicesApiProvider).update(service.id, service.version, draft);
      ref
        ..invalidate(serviceProvider(service.id))
        ..invalidate(serviceCategoriesProvider)
        ..invalidate(servicesListProvider);
      if (context.mounted) showAppMessage(context, 'Changes saved');
      return null;
    } on ApiException catch (e) {
      if (e.code == 'STALE') ref.invalidate(serviceProvider(service.id));
      final fields = formFieldErrors(e);
      if (fields.isEmpty && context.mounted) showAppMessage(context, e.message, error: true);
      return fields;
    }
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.service});

  final SalonService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = service.isActive;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(active ? 'Stop offering' : 'Offer again', style: Theme.of(context).textTheme.titleMedium),
          AppSpacing.gapSm,
          Text(
            active
                ? 'Hides this service from booking and billing. Past bills keep it.'
                : 'Makes this service available for booking and billing again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.of(context).textSecondary),
          ),
          AppSpacing.gapLg,
          AppButton(
            key: const Key('toggle-service-active'),
            label: active ? 'Deactivate service' : 'Reactivate service',
            variant: active ? AppButtonVariant.danger : AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () async {
              if (active) {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Stop offering ${service.name}?',
                  message: 'It will no longer appear in booking or billing. You can reactivate it later.',
                  confirmLabel: 'Deactivate',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
              }
              try {
                await ref.read(servicesApiProvider).setActive(service.id, !active);
                ref.invalidate(serviceProvider(service.id));
                ref.invalidate(servicesListProvider);
                if (context.mounted) showAppMessage(context, active ? 'Service deactivated' : 'Service reactivated');
              } on ApiException catch (e) {
                if (context.mounted) showAppMessage(context, e.message, error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

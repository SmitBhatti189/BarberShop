import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_hover_labels.dart';
import '../../config/app_strings.dart';
import '../../config/assets/app_icons.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_radius.dart';
import '../../config/theme/app_sizes.dart';
import '../../config/theme/app_spacing.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../permissions.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/hover_label.dart';
import '../ui/ui_preferences.dart';
import 'app_brand.dart';
import 'app_destinations.dart';
import 'app_routes.dart';

/// Top bar of every signed-in page: … [profile box ▾] on the right.
/// On phones (no sidebar) it also carries the logo + salon name on the left;
/// on tablet/desktop the brand lives in the sidebar header instead.
class AppNavBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppNavBar({super.key, this.compact = false});

  /// Phone layout: shows the brand, and the profile box shows only the avatar.
  final bool compact;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.navBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final user = ref.watch(currentUserProvider);

    return Material(
      color: colors.navigationBackground,
      child: Container(
        height: AppSizes.navBarHeight,
        padding: EdgeInsets.symmetric(horizontal: compact ? AppSpacing.md : AppSpacing.xl),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: compact
                  ? const Align(alignment: Alignment.centerLeft, child: AppBrand())
                  : const SizedBox.shrink(),
            ),
            // The one main action of the salon, always one click away. Phones
            // reach Billing from the bottom bar instead.
            if (!compact && user != null && user.can(Permissions.billingCreate)) ...[
              AppButton(
                key: const Key('navbar-new-bill'),
                label: 'New bill',
                icon: AppIcons.add,
                variant: AppButtonVariant.gold,
                size: AppButtonSize.small,
                onPressed: () => context.go(AppDestinations.billing.path),
              ),
              AppSpacing.gapMd,
            ],
            if (user != null) ProfileMenu(user: user, compact: compact),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name button that opens: Profile · Settings · Dark mode · Log out.
class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key, required this.user, this.compact = false});

  final CurrentUser user;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: const MenuStyle(minimumSize: WidgetStatePropertyAll(Size(AppSizes.profileMenuWidth, 0))),
      builder: (context, controller, _) => HoverLabel(
        enabled: AppHoverLabels.profileButton,
        message: 'Account',
        child: InkWell(
          key: const Key('profile-button'),
          borderRadius: AppRadius.button,
          overlayColor: colors.overlay,
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(name: user.fullName),
                if (!compact) ...[
                  AppSpacing.gapSm,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(user.fullName, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  ),
                ],
                Icon(AppIcons.dropdown, color: colors.unselectedIcon),
              ],
            ),
          ),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              _Avatar(name: user.fullName),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    Text('Signed in', style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.profile),
          onPressed: () => context.go(AppRoutes.profile),
          child: const Text('Profile'),
        ),
        if (user.can(Permissions.settingsManage))
          MenuItemButton(
            leadingIcon: const Icon(AppIcons.settings),
            onPressed: () => context.go(AppDestinations.settings.path),
            child: const Text('Settings'),
          ),
        MenuItemButton(
          key: const Key('theme-toggle'),
          closeOnActivate: false,
          leadingIcon: Icon(isDark ? AppIcons.darkMode : AppIcons.lightMode),
          trailingIcon: IgnorePointer(
            child: Switch(value: isDark, onChanged: (_) {}),
          ),
          onPressed: () => ref.read(uiPreferencesProvider.notifier).toggleDarkMode(theme.brightness),
          child: const Text('Dark mode'),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: Icon(AppIcons.logout, color: colors.error),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: Text(AppStrings.logout, style: TextStyle(color: colors.error)),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: AppSizes.avatarSize / 2,
      backgroundColor: colors.sidebarBackground,
      foregroundColor: colors.sidebarSelectedText,
      child: Text(
        initials,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: colors.sidebarSelectedText, fontWeight: FontWeight.w600),
      ),
    );
  }
}

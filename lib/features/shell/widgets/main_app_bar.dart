import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';

class MainAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isInitializing;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String currentPath;

  const MainAppBar({
    super.key,
    required this.isInitializing,
    required this.scaffoldKey,
    required this.currentPath,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return AppBar(
      elevation: 2,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      scrolledUnderElevation: 4,
      shadowColor: AppColors.shadowMedium,
      leading: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        onPressed: isInitializing
            ? null
            : () => scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: AppColors.gradientStart,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _getPageTitle(currentPath),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // Theme toggle
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          onPressed: isInitializing
              ? null
              : () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        const SizedBox(width: 8),
        // Notification bell
        _buildNotificationBell(context, ref, colorScheme, isDark),
        const SizedBox(width: 16),
        // Logo
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Image.network(
            'https://hc.andrsn.in/img/anderson-logo.png',
            height: 28,
            errorBuilder: (c, e, s) =>
                const Icon(Icons.local_hospital, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final count = ref.watch(unreadCountProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.xlAll,
          child: InkWell(
            onTap: isInitializing
                ? null
                : () => scaffoldKey.currentState?.openEndDrawer(),
            borderRadius: AppRadius.xlAll,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.notifications_outlined,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                size: 22,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 2,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  String _getPageTitle(String path) {
    if (path.contains('dashboard')) return 'Dashboard';
    if (path.contains('search')) return 'Search';
    if (path.contains('notifications')) return 'Notifications';
    if (path.contains('work_orders')) return 'Work Orders';
    if (path.contains('my_work_orders')) return 'My Tasks';
    if (path.contains('type_orders')) return 'Type Orders';
    if (path.contains('users')) return 'User Management';
    return 'Anderson CRM';
  }
}

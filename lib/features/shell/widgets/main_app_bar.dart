import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shell_providers.dart';

import 'package:anderson_crm_flutter/providers/notification_provider.dart';

class MainAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isDark;
  final bool isInitializing;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String currentPath;

  const MainAppBar({
    super.key,
    required this.isDark,
    required this.isInitializing,
    required this.scaffoldKey,
    required this.currentPath,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      elevation: 2,
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      surfaceTintColor: isDark ? Colors.grey.shade900 : Colors.white,
      scrolledUnderElevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      leading: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
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
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.dashboard_rounded,
              color: Colors.orange.shade600,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _getPageTitle(currentPath),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.grey.shade800,
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
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
          onPressed: isInitializing
              ? null
              : () => ref.read(themeProvider.notifier).state = !isDark,
        ),
        const SizedBox(width: 8), // Space before bell
        // Notification bell
        _buildNotificationBell(context, ref),
        const SizedBox(width: 16), // More space before logo
        // Logo - simple approach like original
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Image.network(
            'https://hc.andrsn.in/img/anderson-logo.png',
            height: 28,
            errorBuilder: (c, e, s) =>
                const Icon(Icons.local_hospital, color: Colors.orange),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBell(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider); // Direct access

    return Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isInitializing
                ? null
                : () => scaffoldKey.currentState?.openEndDrawer(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.notifications_outlined,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
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
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
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
    // Access router state or use path analysis
    // The previous implementation used path string checking, so we keep it.
    return 'Anderson CRM';
  }
}

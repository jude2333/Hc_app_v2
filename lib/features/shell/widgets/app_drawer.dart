import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/database/authorize.dart';
import 'package:anderson_crm_flutter/features/shell/presentation/tenant_selector_sheet.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import '../providers/shell_providers.dart';

class AppDrawer extends ConsumerWidget {
  final bool isDark;
  final String currentPath;

  const AppDrawer({
    super.key,
    required this.isDark,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          _buildDrawerHeader(context, ref),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildSectionTitle('General'),
                _buildNavTile(context, 'Dashboard', Icons.dashboard_rounded,
                    '/dashboard', isDark),
                _buildNavTile(
                    context, 'Search', Icons.search_rounded, '/search', isDark),
                _buildNavTile(context, 'Notifications',
                    Icons.notifications_rounded, '/notifications', isDark),
                const SizedBox(height: 16),
                _buildSectionTitle('Workspace'),
                _buildDynamicMenuItems(context, ref, isDark),
              ],
            ),
          ),
          const Divider(),
          _buildUserActions(context, ref, isDark),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final empName = storage.getFromSession('logged_in_emp_name');
    final centerName = storage.getFromSession('logged_in_tenant_name');
    final initials = storage.getFromSession('initials');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  initials.isNotEmpty ? initials : 'U',
                  style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () {},
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            empName.isNotEmpty ? empName : 'User',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showCenterSelector(context),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    centerName.isNotEmpty ? centerName : 'Select Center',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    color: Colors.white70, size: 16)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicMenuItems(
      BuildContext context, WidgetRef ref, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Authorize.getMenus(ref),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return Column(
          children: snapshot.data!.map((item) {
            return _buildNavTile(
              context,
              (item['title'] ?? 'Menu Item') as String,
              _getIconFromString((item['icon'] ?? '') as String),
              '/${item['link']}',
              isDark,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNavTile(BuildContext context, String title, IconData icon,
      String path, bool isDark) {
    final isSelected = currentPath.startsWith(path) && path != '/';
    final activeColor = Colors.orange;
    final inactiveColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            isSelected ? Colors.orange.withOpacity(0.15) : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? activeColor : inactiveColor),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? activeColor : inactiveColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          Navigator.of(context).pop();
          context.go(path);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildUserActions(BuildContext context, WidgetRef ref, bool isDark) {
    return Column(
      children: [
        _buildNavTile(context, 'Change Password', Icons.lock_reset,
            '/changepassword', isDark),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text('Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
          dense: true,
          onTap: () => _handleLogout(context, ref),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('v1.0.0',
              style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ),
      ],
    );
  }

  IconData _getIconFromString(String iconString) {
    switch (iconString) {
      case 'mdi-view-dashboard':
        return Icons.dashboard_rounded;
      case 'mdi-file-find-outline':
        return Icons.search_rounded;
      case 'mdi-bell-ring':
        return Icons.notifications_rounded;
      case 'mdi-order-bool-ascending':
        return Icons.assignment_ind_rounded;
      case 'mdi-test-tube':
        return Icons.science_rounded;
      case 'mdi-point-of-sale':
        return Icons.receipt_long_rounded;
      case 'mdi-motion-sensor':
        return Icons.people_alt_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  void _showCenterSelector(BuildContext context) {
    showTenantSelector(context);
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // IMPORTANT: Reset notification provider FIRST (before clearing session)
              // This cancels streams while auth tokens are still valid
              ref.read(liveNotificationProvider.notifier).reset();

              // Stop DB sync handlers
              ref.read(dbHandlerProvider).stopSync();

              // Clear CouchDB cached Dio instances (before clearing session)
              // This forces fresh instances with new auth tokens after re-login
              ref.read(couchDbClientProvider).clearCache();

              // Clear session AFTER resetting providers
              ref.read(storageServiceProvider).clearSession();

              // Invalidate the provider to ensure fresh state on next login
              ref.invalidate(liveNotificationProvider);
              ref.read(signedInProvider.notifier).state = false;

              context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

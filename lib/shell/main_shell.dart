import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/core/util.dart';
import '../providers/app_state.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../database/authorize.dart';
import '../services/dbHandler_service.dart';
import '../services/cronJob_service.dart';
import 'tenant_selector_sheet.dart';
import '../providers/notification_provider.dart';

import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';

final themeProvider = StateProvider<bool>((ref) => false);

final signedInProvider = StateProvider<bool>((ref) => false);
final snackbarMessageProvider = StateProvider<String?>((ref) => null);
final initializingProvider = StateProvider<bool>((ref) => false);

final unreadCountsProvider = Provider<int>((ref) {
  return ref.watch(unreadCountProvider);
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  bool _isInitialized = false;
  String _currentPath = '/';

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndInitialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final routerState = GoRouterState.of(context);
      _currentPath = routerState.uri.toString();
    } catch (e) {
      _currentPath = '/';
    }
  }

  Future<void> _checkAuthAndInitialize() async {
    if (!mounted) return;
    try {
      final storageService = ref.read(storageServiceProvider);
      final loggedInMobile = storageService.getFromSession("logged_in_mobile");

      if (loggedInMobile.isNotEmpty) {
        ref.read(signedInProvider.notifier).state = true;
        _initializeInBackground();
      } else {
        ref.read(signedInProvider.notifier).state = false;
        if (mounted && _currentPath != '/login') context.go('/login');
      }
    } catch (e) {
      ref.read(signedInProvider.notifier).state = false;
      if (mounted && _currentPath != '/login') context.go('/login');
    }

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _initializeInBackground() async {
    final cronJob = ref.read(cronJobServiceProvider);
    final dbHandler = ref.read(dbHandlerServiceProvider);
    if (!mounted) return;

    try {
      ref.read(initializingProvider.notifier).state = true;
      cronJob.run();
      ref.read(appNotifierProvider.notifier).setToday(Util.getTodayString());
      await dbHandler.init();
      _loadNotificationsSafely();
      _setupRealtimeListener();
    } catch (e) {
      debugPrint('Background initialization error: $e');
    } finally {
      if (mounted) ref.read(initializingProvider.notifier).state = false;
    }
  }

  StreamSubscription? _realtimeSubscription;

  void _setupRealtimeListener() {
    // Logic moved to LiveNotificationController
  }

  Future<void> _loadNotificationsSafely() async {
    if (!mounted) return;
    try {
      final today = ref.read(appNotifierProvider).today;
      if (today.isEmpty || !_isValidDateFormat(today)) {
        ref.read(appNotifierProvider.notifier).setToday(Util.getTodayString());
      }
      // Trigger initial load via the new provider
      await ref.read(liveNotificationProvider.notifier).loadNotifications();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  bool _isValidDateFormat(String dateString) {
    try {
      DateTime.parse(dateString);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(signedInProvider);
    final isDark = ref.watch(themeProvider);
    final snackbarMessage = ref.watch(snackbarMessageProvider);
    final isInitializing = ref.watch(initializingProvider);
    final dbHandler = ref.read(dbHandlerServiceProvider);

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (!signedIn) {
      return widget.child;
    }

    if (snackbarMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackbarMessage),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
              duration: const Duration(seconds: 2),
            ),
          );
          ref.read(snackbarMessageProvider.notifier).state = null;
        }
      });
    }

    ref.listen<Map<String, dynamic>?>(latestNotificationTriggerProvider,
        (previous, next) {
      if (next != null) {
        // Show the Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next['from_name'] ?? 'New Notification',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        next['msg_header'] ?? 'You have a new message',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.orange,
              onPressed: () {
                // Navigate to notifications page
                context.go('/notifications');
                // Optional: Open the side drawer instead if you prefer
                // _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
        );

        // Reset the trigger so it doesn't fire again on rebuilds
        ref.read(latestNotificationTriggerProvider.notifier).state = null;
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isDark, isInitializing),
      drawer: _buildProfessionalDrawer(isDark),
      endDrawer: _buildNotificationDrawer(isDark),
      body: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(0),
            color: isDark ? Colors.black : Colors.grey.shade50,
            child: RefreshIndicator(
              color: Colors.orange,
              onRefresh: () async {
                await dbHandler.init();

                ref
                    .read(appNotifierProvider.notifier)
                    .setToday(Util.getTodayString());
                await _loadNotificationsSafely();
              },
              child: widget.child,
            ),
          ),
          if (isInitializing)
            Positioned(
              top: 16,
              right: 16,
              child: Card(
                color: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text('Syncing...',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildStatusFooter(isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, bool isInitializing) {
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
            : () => _scaffoldKey.currentState?.openDrawer(),
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
          Text(
            _getPageTitle(_currentPath),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 18,
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
        _buildNotificationBell(isInitializing, isDark),
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

  Widget _buildNotificationBell(bool isInitializing, bool isDark) {
    return Consumer(
      builder: (_, ref, __) {
        final count = ref.watch(unreadCountProvider);
        return Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: isInitializing
                    ? null
                    : () => _scaffoldKey.currentState?.openEndDrawer(),
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
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
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
      },
    );
  }

  Widget _buildProfessionalDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildSectionTitle('General'),
                _buildNavTile(
                    'Dashboard', Icons.dashboard_rounded, '/dashboard', isDark),
                _buildNavTile(
                    'Search', Icons.search_rounded, '/search', isDark),
                _buildNavTile('Notifications', Icons.notifications_rounded,
                    '/notifications', isDark),
                const SizedBox(height: 16),
                _buildSectionTitle('Workspace'),
                _buildDynamicMenuItems(isDark),
              ],
            ),
          ),
          const Divider(),
          _buildUserActions(isDark),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Consumer(
      builder: (context, ref, child) {
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
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _showCenterSelector,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        centerName.isNotEmpty ? centerName : 'Select Center',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
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
      },
    );
  }

  Widget _buildDynamicMenuItems(bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Authorize.getMenus(ref),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return Column(
          children: snapshot.data!.map((item) {
            return _buildNavTile(
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

  Widget _buildNavTile(String title, IconData icon, String path, bool isDark) {
    final isSelected = _currentPath.startsWith(path) && path != '/';
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

  Widget _buildStatusFooter(bool isDark) {
    return Consumer(
      builder: (context, ref, child) {
        final appState = ref.watch(appNotifierProvider);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border:
                Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appState.today,
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    appState.status,
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserActions(bool isDark) {
    return Column(
      children: [
        _buildNavTile(
            'Change Password', Icons.lock_reset, '/changepassword', isDark),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text('Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
          dense: true,
          onTap: _handleLogout,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('v1.0.0',
              style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ),
      ],
    );
  }

  Widget _buildNotificationDrawer(bool isDark) {
    return Drawer(
      width: 320,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            color: isDark ? Colors.grey[800] : Colors.orange.shade50,
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.orange),
                const SizedBox(width: 12),
                Text('Notifications',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (_, ref, __) {
                // OPTIMIZATION: Watch the filtered list directly
                final notifications = ref.watch(unreadListProvider);
                final isLoading = ref
                    .watch(liveNotificationProvider.select((s) => s.isLoading));

                if (isLoading && notifications.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No new notifications',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildNotificationTile(notifications[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Drawer expansion state
  final Set<String> _drawerExpandedRows = {};

  void _toggleDrawerExpanded(String docId) {
    setState(() {
      if (_drawerExpandedRows.contains(docId)) {
        _drawerExpandedRows.remove(docId);
      } else {
        _drawerExpandedRows.add(docId);
      }
    });
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final status = notification['status'];
    final isNew = status == 'New';
    final docId = notification['_id']?.toString() ?? '';
    final isExpanded = _drawerExpandedRows.contains(docId);

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Text(
                (notification['from_name'] != null &&
                        notification['from_name'].toString().isNotEmpty
                    ? notification['from_name'].toString()[0]
                    : 'S'),
                style: const TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          title: Text(notification['from_name'] ?? 'System',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification['msg_header'] ?? '',
                  style: const TextStyle(color: Colors.black87, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (isNew)
                    InkWell(
                      onTap: () => _markNotificationSeen(docId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (isNew) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      notification['updated'] ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
            ),
            onPressed: () => _toggleDrawerExpanded(docId),
          ),
        ),
        if (isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message Detail',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['msg_body'] ?? 'No content',
                  style: const TextStyle(fontSize: 13),
                ),
                if (isNew) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _markNotificationSeen(docId),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark as Seen'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

  void _showCenterSelector() {
    showTenantSelector(context);
  }

  Future<void> _markNotificationSeen(String id) async {
    if (id.isEmpty) return;
    try {
      await ref.read(liveNotificationProvider.notifier).markAsSeen(id);
    } catch (e) {
      debugPrint('Error marking seen: $e');
    }
  }

  void _handleLogout() {
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

              // 1. STOP SYNC LOOP
              ref.read(dbHandlerProvider).stopSync();

              // 2. Clear Session
              ref.read(storageServiceProvider).clearSession();

              // 3. Reset State
              ref.invalidate(liveNotificationProvider);
              ref.read(signedInProvider.notifier).state = false;

              if (mounted) context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String path) {
    if (path.contains('dashboard')) return 'Dashboard';
    if (path.contains('search')) return 'Search';
    if (path.contains('notifications')) return 'Notifications';
    if (path.contains('work_orders')) return 'Work Orders';
    if (path.contains('my_work_orders')) return 'My Tasks';
    if (path.contains('users')) return 'User Management';
    return 'Anderson CRM';
  }
}

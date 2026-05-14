import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/util.dart';
import '../../../providers/app_state.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../../../providers/db_handler_provider.dart';
import '../../../services/dbHandler_service.dart';
import '../../../services/cronJob_service.dart';
import '../../../providers/notification_provider.dart';
import 'package:anderson_crm_flutter/features/tracking/providers/tracking_provider.dart';
import 'package:anderson_crm_flutter/features/tracking/providers/gps_monitor_provider.dart';
import '../providers/shell_providers.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/app_drawer.dart';
import '../widgets/notification_drawer.dart';
import '../widgets/status_footer.dart';

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
  StreamSubscription? _realtimeSubscription;

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

      // Initialize tracking for technicians (auto-starts GPS + WS)
      _initializeTracking();
    } catch (e) {
      debugPrint('Background initialization error: $e');
    } finally {
      if (mounted) ref.read(initializingProvider.notifier).state = false;
    }
  }

  void _initializeTracking() {
    try {
      ref.read(trackingProvider.notifier).initialize();

      // Start GPS monitor for technicians (60s lightweight check)
      final roleName =
          ref.read(storageServiceProvider).getFromSession('role_name');
      if (roleName == 'TECHNICIAN') {
        ref.read(gpsMonitorProvider.notifier).start();
      }
    } catch (e) {
      debugPrint('[MainShell] Tracking init error (non-fatal): $e');
    }
  }

  void _setupRealtimeListener() {}

  Future<void> _loadNotificationsSafely() async {
    if (!mounted) return;
    try {
      final today = ref.read(appNotifierProvider).today;
      if (today.isEmpty || !_isValidDateFormat(today)) {
        ref.read(appNotifierProvider.notifier).setToday(Util.getTodayString());
      }

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
      if (next != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
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
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
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
                    context.go('/notifications');
                  },
                ),
              ),
            );
          } catch (e) {
            debugPrint('[MainShell] Error showing notification snackbar: $e');
          }
        });

        ref.read(latestNotificationTriggerProvider.notifier).state = null;
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: MainAppBar(
        isDark: isDark,
        isInitializing: isInitializing,
        scaffoldKey: _scaffoldKey,
        currentPath: _currentPath,
      ),
      drawer: AppDrawer(
        isDark: isDark,
        currentPath: _currentPath,
      ),
      endDrawer: NotificationDrawer(isDark: isDark),
      body: SelectionArea(
        child: Column(
          children: [
            // GPS-off warning banner (only visible for TECHNICIAN when GPS is disabled)
            _buildGpsBanner(),

            // Main content
            Expanded(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(0),
                    color: isDark ? Colors.black : Colors.grey.shade50,
                    child: RefreshIndicator(
                      color: Colors.orange,
                      onRefresh: () async {
                        final dbHandler = ref.read(dbHandlerServiceProvider);
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: StatusFooter(isDark: isDark),
    );
  }

  /// Persistent banner shown when GPS is disabled (TECHNICIAN only)
  Widget _buildGpsBanner() {
    final isGpsOn = ref.watch(gpsMonitorProvider);
    final roleName =
        ref.read(storageServiceProvider).getFromSession('role_name');

    // Only show for technicians when GPS is OFF
    if (isGpsOn || roleName != 'TECHNICIAN') {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.gps_off, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'GPS is turned off. Please turn on GPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  // Recheck after user returns from settings
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) {
                    ref.read(gpsMonitorProvider.notifier).recheck();
                  }
                },
                child: Text(
                  'Enable GPS',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

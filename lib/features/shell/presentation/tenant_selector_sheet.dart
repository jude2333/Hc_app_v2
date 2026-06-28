import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/postgresService.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/features/tracking/providers/tracking_provider.dart';
import 'package:anderson_crm_flutter/services/dbHandler_service.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import '../providers/shell_providers.dart';
import 'package:anderson_crm_flutter/database/dashboardDb.dart';
import 'package:anderson_crm_flutter/features/dashboard/providers/dashboard_providers.dart';
import 'package:anderson_crm_flutter/features/dashboard/providers/technician_dashboard_providers.dart';
import 'package:anderson_crm_flutter/features/search/providers/search_provider.dart';

final _debounceTimerProvider = StateProvider<DateTime?>((ref) => null);

class TenantSelectorSheet extends ConsumerStatefulWidget {
  const TenantSelectorSheet({super.key});

  @override
  ConsumerState<TenantSelectorSheet> createState() =>
      _TenantSelectorSheetState();
}

class _TenantSelectorSheetState extends ConsumerState<TenantSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _tenantList = [];
  bool _isLoading = false;
  bool _isChangingTenant = false;
  String _currentTenantName = '';

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _currentTenantName = storage.getFromSession('logged_in_tenant_name');
    _loadTenants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTenants([String? search]) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = ref.read(postgresServiceProvider);
      final result = await dbService.getAssignedTenantList(search);

      if (mounted && result is List) {
        setState(() {
          _tenantList = List<Map<String, dynamic>>.from(result);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackbar('Error loading tenants');
        }
      }
    } catch (e) {
      debugPrint('Error loading tenants: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackbar('Error: ${e.toString()}');
      }
    }
  }

  void _debounceSearch(String query) {
    ref.read(_debounceTimerProvider.notifier).state = DateTime.now();

    Future.delayed(const Duration(milliseconds: 500), () {
      final lastUpdate = ref.read(_debounceTimerProvider);
      if (lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inMilliseconds >= 500) {
        _loadTenants(query.isEmpty ? null : query);
      }
    });
  }

  Future<void> _selectTenant(String tenantId, String tenantName) async {
    final storage = ref.read(storageServiceProvider);
    final currentTenantId = storage.getFromSession('logged_in_tenant_id');

    if (tenantId == currentTenantId) {
      _showSnackbar('You are already logged in to $tenantName');
      Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;

    setState(() {
      _isChangingTenant = true;
    });

    try {
      final dbService = ref.read(postgresServiceProvider);
      final result = await dbService.changeTenant(tenantId);

      if (mounted) {
        setState(() {
          _isChangingTenant = false;
        });

        if (result == 200) {
          // Capture build context dependent objects before the async gap
          final router = GoRouter.of(context);
          final navigator = Navigator.of(context);

          // PostgresDB writes to StorageRepository (SharedPreferences) directly,
          // but StorageService has its own in-memory cache that is now stale.
          await storage.reloadCaches();

          final newTenantName = storage.getFromSession('logged_in_tenant_name');

          _showSnackbar('Successfully switched to $newTenantName');

          // Capture all provider references BEFORE pop() disposes the widget.
          // After pop(), ref is dead — using it throws "ref after dispose".
          final tracking = ref.read(trackingProvider.notifier);
          final notifications = ref.read(liveNotificationProvider.notifier);
          final dbHandler = ref.read(dbHandlerProvider);
          final couchDb = ref.read(couchDbClientProvider);
          final initNotifier = ref.read(initializingProvider.notifier);
          final dbHandlerService = ref.read(dbHandlerServiceProvider);

          // Invalidate all dashboard-related providers to clear caches and trigger reload for the new tenant
          ref.invalidate(dashboardDbProvider);
          ref.invalidate(dailyReportProvider);
          ref.invalidate(weeklyReportProvider);
          ref.invalidate(monthlyReportProvider);
          ref.invalidate(yearlyReportProvider);
          ref.invalidate(techDailyProvider);
          ref.invalidate(techWeeklyProvider);
          ref.invalidate(searchProvider);

          navigator.pop();

          // Fire-and-forget: reset app state with captured references
          _resetAppState(
            storage: storage,
            tracking: tracking,
            notifications: notifications,
            dbHandler: dbHandler,
            couchDb: couchDb,
            initNotifier: initNotifier,
            dbHandlerService: dbHandlerService,
            router: router,
          );
        } else {
          _showSnackbar('Failed to change tenant: $result');
        }
      }
    } catch (e) {
      debugPrint('Error changing tenant: $e');
      if (mounted) {
        setState(() {
          _isChangingTenant = false;
        });
        _showSnackbar('Error: ${e.toString()}');
      }
    }
  }

  /// Resets all tenant-scoped app state after a successful tenant switch.
  /// All provider references are pre-captured so this method is safe to
  /// call after the widget is disposed (no ref usage).
  static Future<void> _resetAppState({
    required StorageService storage,
    required dynamic tracking,
    required dynamic notifications,
    required dynamic dbHandler,
    required dynamic couchDb,
    required StateController<bool> initNotifier,
    required dynamic dbHandlerService,
    required GoRouter router,
  }) async {
    // Synchronous teardown
    try { tracking.shutdown(); } catch (_) {}
    notifications.reset();
    dbHandler.stopSync();
    couchDb.clearCache();

    // Reconnect PowerSync with new tenant credentials.
    // This purges old tenant's work orders from local SQLite
    // and re-syncs with the new tenant's data.
    try {
      await PowerSyncService.instance.reconnectForTenantChange(storage);
    } catch (e) {
      debugPrint('[TenantSelector] PowerSync reconnect failed: $e');
    }

    // Re-initialize: sync new tenant DBs, restart notifications & tracking
    initNotifier.state = true;
    try {
      await dbHandlerService.init();
      notifications.loadNotifications();
      try { tracking.initialize(); } catch (_) {}
    } catch (e) {
      debugPrint('[TenantSelector] Re-init after tenant change failed: $e');
    } finally {
      initNotifier.state = false;
    }

    // Navigate to dashboard for fresh data
    router.go('/dashboard');
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Change Tenant',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _debounceSearch,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border(
                left: BorderSide(color: Colors.blue, width: 4),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are in $_currentTenantName',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'Tenant ID',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Tenant Name',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Region',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'State',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _tenantList.isEmpty
                    ? const Center(
                        child: Text('No tenants found'),
                      )
                    : ListView.builder(
                        itemCount: _tenantList.length,
                        itemBuilder: (context, index) {
                          final tenant = _tenantList[index];
                          final tenantId =
                              tenant['tenant_id']?.toString() ?? '';
                          final tenantName =
                              tenant['tenant_name']?.toString() ?? '';
                          final region = tenant['region']?.toString() ?? '';
                          final state = tenant['state']?.toString() ?? '';

                          return InkWell(
                            onTap: _isChangingTenant
                                ? null
                                : () => _selectTenant(tenantId, tenantName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      tenantId,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      tenantName,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      region,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      state,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
            ],
          ),
          if (_isChangingTenant)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'Changing tenant...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void showTenantSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TenantSelectorSheet(),
  );
}

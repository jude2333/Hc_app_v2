import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

import '../database/notifications.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:flutter/material.dart';

class NotificationState {
  final List<Map<String, dynamic>> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<Map<String, dynamic>>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LiveNotificationController extends StateNotifier<NotificationState>
    with WidgetsBindingObserver {
  final Ref ref;
  StreamSubscription? _subscription;
  bool _isRealtimeSetup = false;

  LiveNotificationController(this.ref) : super(const NotificationState()) {
    WidgetsBinding.instance.addObserver(this);

    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  /// Reset the provider state on logout - cancels streams without triggering reload
  void reset() {
    debugPrint(" [Notifications] Resetting notification provider...");
    _subscription?.cancel();
    _subscription = null;
    _isRealtimeSetup = false;
    state = const NotificationState();
    debugPrint(" [Notifications] Provider reset complete");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _init() async {
    if (!mounted) return;

    // Check if user is logged in before loading notifications
    // This prevents 401 errors when provider is recreated after logout
    final storage = ref.read(storageServiceProvider);
    final token = storage.getFromSession("pg_admin");
    if (token == null || token.isEmpty) {
      debugPrint(" [Notifications] Skipping init - user not logged in");
      return;
    }

    state = state.copyWith(isLoading: true);

    Future.microtask(() async {
      await loadNotifications();
    });
  }

  Future<void> loadNotifications() async {
    if (!state.isLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final service = ref.read(notificationDBServiceProvider);
      final list = await service.listRemoteData('All');

      list.sort((a, b) {
        String dateA = a['updated_at']?.toString() ?? '';
        String dateB = b['updated_at']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        state = state.copyWith(notifications: list, isLoading: false);

        if (!_isRealtimeSetup) {
          Future.microtask(() => _setupRealtimeListener());
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }
  }

  void _setupRealtimeListener() {
    _subscription?.cancel();
    _isRealtimeSetup = true;

    final dbHandler = ref.read(dbHandlerProvider);
    final notificationsDbName =
        dbHandler.resolveName('hc_notifications') ?? 'hc_notifications';
    debugPrint("Notification db name >>>:$notificationsDbName");

    final stream = dbHandler.startContinuousStream(notificationsDbName);

    _subscription = stream.listen(
      (Map<String, dynamic> event) {
        if (!mounted) return;

        try {
          final doc = event['doc'];
          final String docId = event['id'] ?? '';
          final bool isDeleted = event['deleted'] ?? false;

          final storage = ref.read(storageServiceProvider);
          final String currentEmpIdStr =
              storage.getFromSession("logged_in_emp_id") ?? "0";

          if (!isDeleted && doc != null) {
            final String toId = doc['to_id']?.toString() ?? "";
            if (toId != currentEmpIdStr) return;
          }

          final List<Map<String, dynamic>> updatedList =
              List.from(state.notifications);

          if (isDeleted) {
            updatedList.removeWhere((item) => item['_id'] == docId);
          } else if (doc != null) {
            try {
              if (doc['updated_at'] != null) {
                doc['updated'] = doc['updated_at'].toString();
              }
            } catch (e) {/* ignore */}

            final index =
                updatedList.indexWhere((item) => item['_id'] == docId);

            if (index != -1) {
              updatedList[index] = doc;
            } else {
              updatedList.insert(0, doc);

              if (doc['status'] == 'New') {
                Future.microtask(() {
                  ref.read(latestNotificationTriggerProvider.notifier).state =
                      doc;
                });
              }
            }
          }

          updatedList.sort((a, b) {
            String dateA = a['updated_at']?.toString() ?? '';
            String dateB = b['updated_at']?.toString() ?? '';
            return dateB.compareTo(dateA);
          });

          state = state.copyWith(notifications: updatedList);
        } catch (e) {
          debugPrint('Error merging notification: $e');
        }
      },
      onError: (error) {
        debugPrint('Stream error: $error');
      },
      cancelOnError: false,
    );
  }

  Future<void> markAsSeen(String docId) async {
    if (docId.isEmpty) return;

    final currentList = List<Map<String, dynamic>>.from(state.notifications);
    final index = currentList.indexWhere((item) => item['_id'] == docId);

    if (index != -1) {
      final item = Map<String, dynamic>.from(currentList[index]);
      item['status'] = 'Seen';
      currentList[index] = item;
      state = state.copyWith(notifications: currentList);
    }

    try {
      final service = ref.read(notificationDBServiceProvider);
      await service.markAsSeen(docId);
    } catch (e) {
      debugPrint('Error marking as seen: $e');
      await loadNotifications();
    }
  }
}

final liveNotificationProvider =
    StateNotifierProvider<LiveNotificationController, NotificationState>((ref) {
  final controller = LiveNotificationController(ref);
  ref.keepAlive();
  return controller;
});

final unreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(liveNotificationProvider);
  return state.notifications.where((n) => n['status'] == 'New').length;
});

final unreadListProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final state = ref.watch(liveNotificationProvider);
  return state.notifications.where((n) => n['status'] == 'New').toList();
});

final latestNotificationTriggerProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

final notificationDbProvider = Provider<NotificationDB>((ref) {
  final dbHandler = ref.watch(dbHandlerProvider);
  final couchDb = ref.watch(couchDbClientProvider);
  final storage = ref.watch(storageRepositoryProvider);
  return NotificationDB(dbHandler, couchDb, storage);
});

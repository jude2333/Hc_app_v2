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
    // 2. Start observing App Lifecycle immediately upon creation
    WidgetsBinding.instance.addObserver(this);
    // ✅ OPTIMIZATION: Don't await _init - let it run in background
    _init();
  }

  @override
  void dispose() {
    // 3. Stop observing when the provider is finally killed (e.g. app restart)
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  // 4. Handle Background/Foreground globally
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint("zzz App Paused (Global) - Stopping Sync");

      // Stop the DBHandler loop
      ref.read(dbHandlerProvider).stopSync();

      // Optionally cancel the subscription to be safe
      _subscription?.cancel();
      _subscription = null;
      _isRealtimeSetup = false;
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("☀️ App Resumed (Global) - Restarting Sync");

      // We need to restart the listener.
      // Checking if _subscription is null prevents double-subscribing
      if (_subscription == null) {
        _setupRealtimeListener();
        // Optional: Do a hard refresh to catch up on missed data
        loadNotifications();
      }
    }
  }

  // ✅ OPTIMIZATION: Non-blocking init - sets loading state immediately
  Future<void> _init() async {
    // Set loading state immediately so UI can show skeleton
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    // ✅ Use scheduleMicrotask to let the UI render first
    Future.microtask(() async {
      await loadNotifications();
    });
  }

  // ✅ OPTIMIZATION: Separated realtime setup from data loading
  Future<void> loadNotifications() async {
    // Only set loading if not already loading (avoids flicker on refresh)
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

        // ✅ OPTIMIZATION: Setup realtime AFTER data is loaded and UI has rendered
        if (!_isRealtimeSetup) {
          // Defer realtime setup to avoid blocking
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
    // 1. Clean up old subscription
    _subscription?.cancel();
    _isRealtimeSetup = true; // ✅ Mark as setup

    final dbHandler = ref.read(dbHandlerProvider);

    // 2. Start the stream
    final stream = dbHandler.startContinuousStream('hc_notifications');

    _subscription = stream.listen(
      (Map<String, dynamic> event) {
        // The stream gives us ONE event at a time
        if (!mounted) return;

        try {
          final doc = event['doc'];
          final String docId = event['id'] ?? '';
          final bool isDeleted = event['deleted'] ?? false;

          final storage = ref.read(storageServiceProvider);
          final String currentEmpIdStr =
              storage.getFromSession("logged_in_emp_id") ?? "0";

          // --- FILTERING ---
          // Ignore if it doesn't belong to the logged-in user
          if (!isDeleted && doc != null) {
            final String toId = doc['to_id']?.toString() ?? "";
            if (toId != currentEmpIdStr) return;
          }

          // --- MERGE LOGIC (THE FIX) ---

          // A. Create a modifiable COPY of the OLD list
          final List<Map<String, dynamic>> updatedList =
              List.from(state.notifications);

          if (isDeleted) {
            // Case 1: Delete
            updatedList.removeWhere((item) => item['_id'] == docId);
          } else if (doc != null) {
            // Case 2: Insert or Update

            // Format Date to match your UI format
            try {
              if (doc['updated_at'] != null) {
                doc['updated'] = doc['updated_at'].toString();
              }
            } catch (e) {/* ignore */}

            // Check if this row already exists
            final index =
                updatedList.indexWhere((item) => item['_id'] == docId);

            if (index != -1) {
              // Update the existing row
              updatedList[index] = doc;
            } else {
              // Insert the NEW row at the TOP
              updatedList.insert(0, doc);

              // snackbar message
              if (doc['status'] == 'New') {
                // We use a post-frame callback to ensure we don't update providers during a build
                Future.microtask(() {
                  ref.read(latestNotificationTriggerProvider.notifier).state =
                      doc;
                });
              }
            }
          }

          // --- SORTING ---
          // Ensure the newest is always on top
          updatedList.sort((a, b) {
            String dateA = a['updated_at']?.toString() ?? '';
            String dateB = b['updated_at']?.toString() ?? '';
            return dateB.compareTo(dateA);
          });

          // B. Save the COMBINED list (Old + New)
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

  // @override
  // void dispose() {
  //   _subscription?.cancel();
  //   super.dispose();
  // }
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

// Optimized List for Drawer
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

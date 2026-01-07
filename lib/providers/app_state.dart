import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppState {
  final String status;
  final String workOrder;
  final String today;
  final String notifications;
  final List<Map<String, dynamic>> notificationList;

  const AppState({
    this.status = '',
    this.workOrder = '',
    this.today = '',
    this.notifications = '',
    this.notificationList = const [],
  });

  AppState copyWith({
    String? status,
    String? workOrder,
    String? today,
    String? notifications,
    List<Map<String, dynamic>>? notificationList,
  }) =>
      AppState(
        status: status ?? this.status,
        workOrder: workOrder ?? this.workOrder,
        today: today ?? this.today,
        notifications: notifications ?? this.notifications,
        notificationList: notificationList ?? this.notificationList,
      );
}

/* ----------  NOTIFIER  (actions)  ---------- */
class AppNotifier extends StateNotifier<AppState> {
  AppNotifier() : super(AppState(today: Util.getTodayString()));

  // Notifications are now handled by LiveNotificationController in notification_provider.dart

  /* ----- mutations ----- */
  void setStatus(String v) => state = state.copyWith(status: v);
  void setWorkOrder(String v) => state = state.copyWith(workOrder: v);
  void setToday(String v) => state = state.copyWith(today: v);
  void setNotifications(String v) => state = state.copyWith(notifications: v);
}

/* ----------  PROVIDERS  ---------- */
final appNotifierProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);

// Notification providers moved to lib/providers/notification_provider.dart

/* ---- convenience selectors ---- */
final notificationsProvider = Provider<String>(
  (ref) => ref.watch(appNotifierProvider.select((s) => s.notifications)),
);

final statusProvider = Provider<String>(
  (ref) => ref.watch(appNotifierProvider.select((s) => s.status)),
);

final workOrderProvider = Provider<String>(
  (ref) => ref.watch(appNotifierProvider.select((s) => s.workOrder)),
);

final todayProvider = Provider<String>(
  (ref) => ref.watch(appNotifierProvider.select((s) => s.today)),
);

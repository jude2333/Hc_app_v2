import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import '../providers/notifications_page_provider.dart';
import '../widgets/notification_header.dart';
import '../widgets/notification_search.dart';
import '../widgets/notification_skeleton.dart';
import '../widgets/notification_mobile_view.dart';
import '../widgets/notification_desktop_view.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final state = ref.watch(liveNotificationProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    // Filter notifications based on search query
    List<Map<String, dynamic>> filteredNotifications = state.notifications;
    if (searchQuery.isNotEmpty) {
      filteredNotifications = Util.search(
        state.notifications,
        searchQuery.toLowerCase(),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const NotificationHeader(),

          // Search Bar
          const NotificationSearch(),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _buildContent(
              context,
              ref,
              isMobile,
              state.isLoading,
              state.error,
              filteredNotifications,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isMobile,
    bool isLoading,
    String? errorMessage,
    List<Map<String, dynamic>> notifications,
  ) {
    // Show skeleton during initial load
    if (isLoading && notifications.isEmpty) {
      return const NotificationSkeleton();
    }

    // Show error state
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(liveNotificationProvider.notifier)
                  .loadNotifications(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notifications found'),
          ],
        ),
      );
    }

    // Show appropriate view based on screen size
    return isMobile
        ? NotificationMobileView(notifications: notifications)
        : NotificationDesktopView(notifications: notifications);
  }
}

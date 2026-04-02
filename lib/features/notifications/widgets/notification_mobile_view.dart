import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import '../providers/notifications_page_provider.dart';
import 'notification_status_chip.dart';
import 'notification_expanded.dart';

class NotificationMobileView extends ConsumerWidget {
  final List<Map<String, dynamic>> notifications;

  const NotificationMobileView({
    super.key,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedRows = ref.watch(expandedRowsProvider);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(liveNotificationProvider.notifier).loadNotifications(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final docId = notification['_id']?.toString() ?? '';
          final isExpanded = expandedRows.contains(docId);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    notification['from_name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification['msg_header'] ?? 'No subject'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          NotificationStatusChip(notification: notification),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(notification['updated']),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.orange,
                    ),
                    onPressed: () => _toggleExpanded(ref, docId),
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: NotificationExpanded(notification: notification),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleExpanded(WidgetRef ref, String docId) {
    final current = ref.read(expandedRowsProvider);
    final updated = Set<String>.from(current);
    if (updated.contains(docId)) {
      updated.remove(docId);
    } else {
      updated.add(docId);
    }
    ref.read(expandedRowsProvider.notifier).state = updated;
  }

  static String _formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd-MM-yyyy hh:mm a').format(dt);
    } catch (_) {
      return value.toString();
    }
  }
}

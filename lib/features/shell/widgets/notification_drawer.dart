import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class NotificationDrawer extends ConsumerStatefulWidget {
  const NotificationDrawer({super.key});

  @override
  ConsumerState<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends ConsumerState<NotificationDrawer> {
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

  Future<void> _markNotificationSeen(String id) async {
    if (id.isEmpty) return;
    try {
      await ref.read(liveNotificationProvider.notifier).markAsSeen(id);
    } catch (e) {
      debugPrint('Error marking seen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      width: 320,
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Text('Notifications',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
              ],
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (_, ref, __) {
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
                            size: 48,
                            color: colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No new notifications',
                            style: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildNotificationTile(notifications[index], colorScheme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
      Map<String, dynamic> notification, ColorScheme colorScheme) {
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
            backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
            child: Text(
                (notification['from_name'] != null &&
                        notification['from_name'].toString().isNotEmpty
                    ? notification['from_name'].toString()[0]
                    : 'S'),
                style: const TextStyle(
                    color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ),
          title: Text(notification['from_name'] ?? 'System',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification['msg_header'] ?? '',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 13)),
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
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.secondary),
                          borderRadius: AppRadius.xlAll,
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            color: AppColors.secondary,
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
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.4)),
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
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            onPressed: () => _toggleDrawerExpanded(docId),
          ),
        ),
        if (isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainerHighest,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Detail',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
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
                        foregroundColor: AppColors.success,
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
}

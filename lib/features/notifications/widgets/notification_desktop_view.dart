import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notifications_page_provider.dart';
import 'notification_status_chip.dart';
import 'notification_expanded.dart';

/// Desktop table view for notifications
class NotificationDesktopView extends ConsumerWidget {
  final List<Map<String, dynamic>> notifications;

  const NotificationDesktopView({
    super.key,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedRows = ref.watch(expandedRowsProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 1,
      child: Column(
        children: [
          // Table Header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Name', flex: 2),
                _buildHeaderCell('Message', flex: 3),
                _buildHeaderCell('Status', flex: 1),
                _buildHeaderCell('Date Time', flex: 2),
                _buildHeaderCell('', flex: 1),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final docId = notification['_id']?.toString() ?? '';
                final isExpanded = expandedRows.contains(docId);

                return Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _toggleExpanded(ref, docId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              _buildDataCell(
                                notification['from_name'] ?? 'Unknown',
                                flex: 2,
                              ),
                              _buildDataCell(
                                notification['msg_header'] ?? 'No subject',
                                flex: 3,
                              ),
                              _buildStatusCell(notification, flex: 1),
                              _buildDataCell(
                                notification['updated'] ?? '',
                                flex: 2,
                              ),
                              _buildExpandCell(isExpanded, flex: 1),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: NotificationExpanded(notification: notification),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildStatusCell(Map<String, dynamic> notification,
      {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: NotificationStatusChip(notification: notification),
      ),
    );
  }

  Widget _buildExpandCell(bool isExpanded, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

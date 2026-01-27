import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import '../providers/notifications_page_provider.dart';

class NotificationStatusChip extends ConsumerWidget {
  final Map<String, dynamic> notification;

  const NotificationStatusChip({
    super.key,
    required this.notification,
  });

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.red;
    if (status == 'New') return Colors.blue;
    return Colors.grey;
  }

  Future<void> _markAsSeen(BuildContext context, WidgetRef ref) async {
    final docId = notification['_id']?.toString() ?? '';
    if (docId.isEmpty || docId == 'placeholder') return;

    ref.read(processingDocIdProvider.notifier).state = docId;

    try {
      await ref.read(liveNotificationProvider.notifier).markAsSeen(docId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully marked as seen'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(processingDocIdProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = notification['status'];
    final docId = notification['_id']?.toString() ?? '';
    final canMarkSeen = status == 'New' && docId != 'placeholder';
    final processingDocId = ref.watch(processingDocIdProvider);
    final isProcessing = processingDocId == docId;

    return InkWell(
      onTap:
          canMarkSeen && !isProcessing ? () => _markAsSeen(context, ref) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: _getStatusColor(status)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status ?? 'Unknown',
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 12,
              ),
            ),
            if (isProcessing) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

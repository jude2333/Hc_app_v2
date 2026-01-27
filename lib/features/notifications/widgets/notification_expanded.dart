import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import '../providers/notifications_page_provider.dart';

class NotificationExpanded extends ConsumerWidget {
  final Map<String, dynamic> notification;

  const NotificationExpanded({
    super.key,
    required this.notification,
  });

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message Detail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          notification['msg_body'] ?? 'No content',
          style: const TextStyle(fontSize: 14),
        ),
        if (canMarkSeen) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : () => _markAsSeen(context, ref),
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Seen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

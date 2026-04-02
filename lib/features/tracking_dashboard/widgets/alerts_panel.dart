import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/tracking_models.dart';

/// Alerts panel showing recent tracking alerts with severity indicators.
class AlertsPanel extends StatelessWidget {
  final List<TrackingAlert> alerts;

  const AlertsPanel({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No alerts',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: alerts.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _AlertItem(alert: alert);
      },
    );
  }
}

class _AlertItem extends StatelessWidget {
  final TrackingAlert alert;

  const _AlertItem({required this.alert});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;

    if (alert.isCritical) {
      bgColor = Colors.red.withOpacity(0.06);
      borderColor = Colors.red.withOpacity(0.3);
    } else {
      bgColor = Colors.orange.withOpacity(0.06);
      borderColor = Colors.orange.withOpacity(0.3);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: alert.isRead ? Colors.transparent : bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alert.isRead ? Colors.grey.withOpacity(0.15) : borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!alert.isRead)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _formatAlertType(alert.alertType),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: alert.isCritical ? Colors.red[700] : Colors.orange[800],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(alert.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
                if (alert.message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.message!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (alert.technicianName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.technicianName!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAlertType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, hh:mm a').format(dt.toLocal());
  }
}

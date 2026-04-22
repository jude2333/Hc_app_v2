import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
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
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No alerts',
              style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: alerts.length,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
    final Color textColor;

    if (alert.isCritical) {
      bgColor = AppColors.error.withValues(alpha: 0.05);
      borderColor = AppColors.error.withValues(alpha: 0.3);
      textColor = AppColors.error;
    } else {
      bgColor = AppColors.warning.withValues(alpha: 0.05);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      textColor = AppColors.activityStationary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: alert.isRead ? AppColors.surface : bgColor,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: alert.isRead ? AppColors.divider : borderColor,
        ),
        boxShadow: alert.isRead ? null : [
          BoxShadow(color: AppColors.shadowLight, blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!alert.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      _formatAlertType(alert.alertType),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(alert.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                if (alert.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.message!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (alert.technicianName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    alert.technicianName!,
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
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

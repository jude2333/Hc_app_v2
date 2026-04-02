import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracking_provider.dart';

/// A small chip/badge that shows the current tracking status.
/// Can be placed in any part of the UI (drawer, bottom bar, etc.)
///
/// Shows:
/// - "Tracking Active" (green) when tracking + connected
/// - "Tracking (Offline)" (orange) when tracking but WS disconnected
/// - "Tracking Off" (red) when not tracking
class TrackingStatusChip extends ConsumerWidget {
  final bool showLabel;
  const TrackingStatusChip({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingProvider);

    final Color bgColor;
    final Color textColor;
    final String label;
    final IconData icon;

    if (trackingState.isTracking && trackingState.isConnected) {
      bgColor = Colors.green.withOpacity(0.15);
      textColor = Colors.green;
      label = 'Tracking Active';
      icon = Icons.location_on;
    } else if (trackingState.isTracking && !trackingState.isConnected) {
      bgColor = Colors.orange.withOpacity(0.15);
      textColor = Colors.orange;
      label = 'Tracking (Offline)';
      icon = Icons.location_searching;
    } else {
      bgColor = Colors.red.withOpacity(0.15);
      textColor = Colors.red;
      label = 'Tracking Off';
      icon = Icons.location_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (trackingState.cachedPings > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${trackingState.cachedPings}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

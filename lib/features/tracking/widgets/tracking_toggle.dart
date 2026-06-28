import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracking_provider.dart';

class TrackingToggle extends ConsumerWidget {
  const TrackingToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingProvider);

    final Color statusColor;
    final String tooltip;

    if (trackingState.isTracking && trackingState.isConnected) {
      statusColor = Colors.green;
      tooltip = 'Tracking active';
    } else if (trackingState.isTracking && !trackingState.isConnected) {
      statusColor = Colors.orange;
      tooltip = 'Tracking (offline — ${trackingState.cachedPings} cached)';
    } else {
      statusColor = Colors.red;
      tooltip = 'Tracking off';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status dot
        Tooltip(
          message: tooltip,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Toggle switch
        Switch(
          value: trackingState.isTracking,
          onChanged: (value) {
            ref.read(trackingProvider.notifier).toggleTracking();
          },
          activeColor: Colors.green,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

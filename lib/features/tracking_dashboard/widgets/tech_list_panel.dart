import 'package:flutter/material.dart';
import '../data/tracking_models.dart';
import 'package:intl/intl.dart';

/// Side panel showing the list of technicians with their current status.
class TechListPanel extends StatelessWidget {
  final List<TechnicianStatus> technicians;
  final TechnicianStatus? selectedTech;
  final Function(TechnicianStatus) onTechSelected;

  const TechListPanel({
    super.key,
    required this.technicians,
    this.selectedTech,
    required this.onTechSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (technicians.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No technicians', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.people, size: 18),
              const SizedBox(width: 6),
              Text(
                'Technicians (${technicians.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              // Online count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${technicians.where((t) => t.isOnline).length} online',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child: ListView.builder(
            itemCount: technicians.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final tech = technicians[index];
              final isSelected = selectedTech?.technicianId == tech.technicianId;

              return _TechListItem(
                tech: tech,
                isSelected: isSelected,
                onTap: () => onTechSelected(tech),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TechListItem extends StatelessWidget {
  final TechnicianStatus tech;
  final bool isSelected;
  final VoidCallback onTap;

  const _TechListItem({
    required this.tech,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusEmoji;

    if (!tech.isOnline) {
      statusColor = Colors.red;
      statusEmoji = '🔴';
    } else if (tech.statusLabel == 'Idle') {
      statusColor = Colors.orange;
      statusEmoji = '🟡';
    } else {
      statusColor = Colors.green;
      statusEmoji = '🟢';
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.08) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
        ),
        child: Row(
          children: [
            // Status dot
            Text(statusEmoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tech.technicianName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        tech.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (tech.lastSeenAt != null) ...[
                        Text(
                          ' · ${_timeAgo(tech.lastSeenAt!)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Distance + battery
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (tech.todayDistance > 0)
                  Text(
                    '${tech.todayDistance.toStringAsFixed(1)} km',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                if (tech.lastBattery != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tech.lastBattery! < 20
                            ? Icons.battery_alert
                            : Icons.battery_std,
                        size: 12,
                        color: tech.lastBattery! < 20 ? Colors.red : Colors.grey,
                      ),
                      Text(
                        '${tech.lastBattery}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: tech.lastBattery! < 20 ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

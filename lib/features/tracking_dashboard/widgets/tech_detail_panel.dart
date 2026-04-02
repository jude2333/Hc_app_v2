import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/tracking_models.dart';

/// Detail panel showing information about a selected technician.
class TechDetailPanel extends StatelessWidget {
  final TechnicianStatus? technician;
  final DateTime selectedDate;

  const TechDetailPanel({
    super.key,
    this.technician,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (technician == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Select a technician to view details',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    final tech = technician!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name + status
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tech.isOnline ? Colors.green : Colors.grey,
                radius: 18,
                child: Text(
                  tech.technicianName.isNotEmpty
                      ? tech.technicianName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech.technicianName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      tech.statusLabel,
                      style: TextStyle(
                        color: tech.isOnline ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Stats grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                icon: Icons.route,
                label: 'Distance',
                value: '${tech.todayDistance.toStringAsFixed(1)} km',
                color: Colors.blue,
              ),
              _StatCard(
                icon: Icons.speed,
                label: 'Speed',
                value: '${tech.speedKmh.toStringAsFixed(1)} km/h',
                color: Colors.orange,
              ),
              _StatCard(
                icon: Icons.battery_std,
                label: 'Battery',
                value: tech.lastBattery != null ? '${tech.lastBattery}%' : '--',
                color: (tech.lastBattery ?? 100) < 20 ? Colors.red : Colors.green,
              ),
              _StatCard(
                icon: Icons.pin_drop,
                label: 'Pings',
                value: '${tech.todayPings}',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Location info
          if (tech.hasLocation) ...[
            _InfoRow(Icons.location_on, 'Location',
                '${tech.lastLatitude!.toStringAsFixed(5)}, ${tech.lastLongitude!.toStringAsFixed(5)}'),
            if (tech.lastAccuracy != null)
              _InfoRow(Icons.gps_fixed, 'Accuracy',
                  '${tech.lastAccuracy!.toStringAsFixed(1)} meters'),
          ],
          if (tech.lastSeenAt != null)
            _InfoRow(Icons.access_time, 'Last seen',
                DateFormat('hh:mm a, MMM d').format(tech.lastSeenAt!.toLocal())),
          if (tech.currentWorkOrder != null)
            _InfoRow(Icons.work, 'Current WO', tech.currentWorkOrder!),
          if (tech.lastActivity != null)
            _InfoRow(Icons.directions_walk, 'Activity', tech.lastActivity!),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

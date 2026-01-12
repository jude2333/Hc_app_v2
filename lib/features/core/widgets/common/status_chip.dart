import 'package:flutter/material.dart';

/// Status chip for work order status display (bordered style).
/// Used by both Manager and Technician work order pages.
class StatusChip extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;

  const StatusChip({
    super.key,
    required this.status,
    this.onTap,
  });

  Color _getColor(String status) {
    final s = status.toLowerCase().trim();
    if (s.startsWith('un')) return Colors.red;
    if (s == 'assigned') return Colors.blue;
    if (s == 'cancelled') return Colors.grey;
    if (s == 'finished') return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(status);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.isEmpty ? 'N/A' : status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: chip,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: chip,
    );
  }
}

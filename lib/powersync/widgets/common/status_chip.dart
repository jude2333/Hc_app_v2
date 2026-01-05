import 'package:flutter/material.dart';

/// Status chip for work order status display.
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
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

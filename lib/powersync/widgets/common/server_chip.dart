import 'package:flutter/material.dart';

/// Server status chip for work order billing status display.
/// Used by both Manager and Technician work order pages.
class ServerChip extends StatelessWidget {
  final String status;
  final bool showBorder;

  const ServerChip({
    super.key,
    required this.status,
    this.showBorder = true,
  });

  Color _getColor() {
    final s = status.toLowerCase().trim();
    if (s == 'billed') return Colors.green;
    if (s == 'unbilled' || s == 'received') return Colors.red;
    if (s == 'cancelled') return Colors.grey;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    // Transform "Received" to "Unbilled" for display
    final displayText = status == 'Received' ? 'Unbilled' : status;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: showBorder ? Border.all(color: color.withOpacity(0.5)) : null,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

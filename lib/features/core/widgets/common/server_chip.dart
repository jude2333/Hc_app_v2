import 'package:flutter/material.dart';

/// Server status chip for work order billing status display (filled style).
/// Used by both Manager and Technician work order pages.
class ServerChip extends StatelessWidget {
  final String status;
  final bool showBorder;

  const ServerChip({
    super.key,
    required this.status,
    this.showBorder = false,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: showBorder ? Border.all(color: color) : null,
        ),
        child: Text(
          displayText.isEmpty ? 'N/A' : displayText,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

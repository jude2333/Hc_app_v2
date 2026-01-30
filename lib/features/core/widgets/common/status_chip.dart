import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

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
      padding: AppPadding.custom,
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: AppRadius.xsAll,
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
        borderRadius: AppRadius.smAll,
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

class ServerStatusChip extends StatelessWidget {
  final String status;

  const ServerStatusChip({
    super.key,
    required this.status,
  });

  Color _getColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'billed') return Colors.green;
    if (s == 'pending') return Colors.orange;
    if (s == 'processing') return Colors.blue;
    if (s == 'cancelled') return Colors.grey;
    if (s == 'error' || s == 'failed') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: AppPadding.custom,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.xsAll,
        ),
        child: Text(
          status.isEmpty ? 'N/A' : status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

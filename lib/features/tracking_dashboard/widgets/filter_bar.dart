import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Filter bar for the tracking dashboard.
/// Allows filtering by date and technician status.
class FilterBar extends StatelessWidget {
  final DateTime selectedDate;
  final String? statusFilter;
  final Function(DateTime) onDateChanged;
  final Function(String?) onStatusFilterChanged;

  const FilterBar({
    super.key,
    required this.selectedDate,
    this.statusFilter,
    required this.onDateChanged,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Date picker
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (date != null) onDateChanged(date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    _isToday(selectedDate)
                        ? 'Today'
                        : DateFormat('MMM d, yyyy').format(selectedDate),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Status filter chips
          _FilterChip(
            label: 'All',
            isSelected: statusFilter == null,
            onTap: () => onStatusFilterChanged(null),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Online',
            isSelected: statusFilter == 'online',
            onTap: () => onStatusFilterChanged('online'),
            color: Colors.green,
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Idle',
            isSelected: statusFilter == 'idle',
            onTap: () => onStatusFilterChanged('idle'),
            color: Colors.orange,
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Offline',
            isSelected: statusFilter == 'offline',
            onTap: () => onStatusFilterChanged('offline'),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    this.isSelected = false,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.blue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? chipColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

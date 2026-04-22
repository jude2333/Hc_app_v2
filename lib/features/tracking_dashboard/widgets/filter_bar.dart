import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../providers/tracking_ui_providers.dart';

/// Filter bar for the tracking dashboard.
/// Uses Riverpod to directly read and mutate dashboard state safely.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final statusFilter = ref.watch(statusFilterProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Elegant Date picker chip
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                ref.read(selectedDateProvider.notifier).state = date;
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _isToday(selectedDate)
                        ? 'Today, ${DateFormat('MMM d').format(selectedDate)}'
                        : DateFormat('MMM d, yyyy').format(selectedDate),
                    style: AppTextStyles.buttonText.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: AppColors.divider),
          const SizedBox(width: 16),

          // Status filter chips (horizontally scrollable if tight space)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: statusFilter == null,
                    onTap: () => ref.read(statusFilterProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Online',
                    isSelected: statusFilter == 'online',
                    onTap: () => ref.read(statusFilterProvider.notifier).state = 'online',
                    activeColor: AppColors.trackOnline,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Idle',
                    isSelected: statusFilter == 'idle',
                    onTap: () => ref.read(statusFilterProvider.notifier).state = 'idle',
                    activeColor: AppColors.trackIdle,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Offline',
                    isSelected: statusFilter == 'offline',
                    onTap: () => ref.read(statusFilterProvider.notifier).state = 'offline',
                    activeColor: AppColors.trackOffline,
                  ),
                ],
              ),
            ),
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
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    this.isSelected = false,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              )
            : AppDecorations.inactiveFilterPill,
        child: Text(
          label,
          style: AppTextStyles.chipText.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

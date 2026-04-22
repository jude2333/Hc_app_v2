import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../data/tracking_models.dart';
import '../providers/tracking_ws_provider.dart';
import '../providers/tracking_ui_providers.dart';

/// Side panel showing the list of technicians with their current status.
class TechListPanel extends ConsumerWidget {
  const TechListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsState = ref.watch(dashboardWsProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final selectedTech = ref.watch(selectedTechProvider);

    // Apply local filter
    final technicians = wsState.technicianList.where((t) {
      if (statusFilter == null) return true;
      if (statusFilter == 'online') return t.isOnline;
      if (statusFilter == 'offline') return !t.isOnline;
      if (statusFilter == 'idle') return t.isOnline && t.statusLabel == 'Idle';
      return true;
    }).toList();

    if (technicians.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 40, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.sm),
            const Text('No technicians found', style: AppTextStyles.caption),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.people, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Technicians (${technicians.length})',
                style: AppTextStyles.buttonText.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              // Online count
              Container(
                padding: AppPadding.badge,
                decoration: AppDecorations.pillBadge(AppColors.trackOnline),
                child: Text(
                  '${technicians.where((t) => t.isOnline).length} online',
                  style: AppTextStyles.chipText.copyWith(
                    color: AppColors.trackOnline,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        // List
        Expanded(
          child: ListView.builder(
            itemCount: technicians.length,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemBuilder: (context, index) {
              final tech = technicians[index];
              final isSelected = selectedTech?.technicianId == tech.technicianId;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                child: _TechListItem(
                  tech: tech,
                  isSelected: isSelected,
                  onTap: () {
                    ref.read(selectedTechProvider.notifier).state = tech;
                  },
                ),
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
    Color statusColor;
    if (!tech.isOnline) {
      statusColor = AppColors.trackOffline;
    } else if (tech.statusLabel == 'Idle') {
      statusColor = AppColors.trackIdle;
    } else {
      statusColor = AppColors.trackOnline;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Text(
                  tech.technicianName.isNotEmpty ? tech.technicianName[0].toUpperCase() : '?',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech.technicianName.isNotEmpty ? tech.technicianName : 'Tech #${tech.technicianId}',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tech.statusLabel,
                          style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w500),
                        ),
                        if (tech.lastSeenAt != null) ...[
                          Text(
                            ' · ${_timeAgo(tech.lastSeenAt!)}',
                            style: AppTextStyles.caption,
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
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
                    ),
                  if (tech.lastBattery != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tech.lastBattery! < 20 ? Icons.battery_alert : Icons.battery_std,
                          size: 12,
                          color: tech.lastBattery! < 20 ? AppColors.error : AppColors.textSecondary,
                        ),
                        Text(
                          '${tech.lastBattery}%',
                          style: AppTextStyles.caption.copyWith(
                            color: tech.lastBattery! < 20 ? AppColors.error : AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
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

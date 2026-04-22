import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../data/tracking_models.dart';
import '../data/tracking_repository.dart';
import '../providers/tracking_ui_providers.dart';

/// Activity timeline showing segments of a technician's day.
/// Each segment represents a continuous period of one activity type.
class TimelinePanel extends ConsumerStatefulWidget {
  final TechnicianStatus? technician; // Legacy prop
  final DateTime? selectedDate; // Legacy prop
  final String token;

  const TimelinePanel({
    super.key,
    this.technician,
    this.selectedDate,
    required this.token,
  });

  @override
  ConsumerState<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<TimelinePanel> {
  List<TimelineSegment> _segments = [];
  bool _loading = false;
  String? _error;
  int? _lastLoadedTechId;
  String? _lastLoadedDate;

  Future<void> _loadTimeline(int techId, String dateStr) async {
    // Don't reload if same tech+date
    if (techId == _lastLoadedTechId && dateStr == _lastLoadedDate) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = TrackingRepository(token: widget.token);
      final segments = await repo.getTimeline(techId, dateStr);
      
      if (mounted) {
        setState(() {
          _lastLoadedTechId = techId;
          _lastLoadedDate = dateStr;
          _segments = segments;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastLoadedTechId = techId;
          _lastLoadedDate = dateStr;
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTech = ref.watch(selectedTechProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Trigger data load when tech or date changes (safe — only in build)
    if (selectedTech != null &&
        (selectedTech.technicianId != _lastLoadedTechId || dateStr != _lastLoadedDate) &&
        !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTimeline(selectedTech.technicianId, dateStr);
      });
    }

    if (selectedTech == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 40, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Select a technician to view timeline',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text('Loading timeline...', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            Text('Error loading timeline', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            TextButton(
              onPressed: () {
                _lastLoadedTechId = null;
                final tech = ref.read(selectedTechProvider);
                final date = ref.read(selectedDateProvider);
                if (tech != null) {
                  _loadTimeline(tech.technicianId, DateFormat('yyyy-MM-dd').format(date));
                }
              }, 
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 36, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No activity recorded on ${DateFormat('MMM d').format(selectedDate)}',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    // Summary stats
    final totalDuration = _segments.fold<int>(0, (sum, s) => sum + s.durationMin);
    final totalPings = _segments.fold<int>(0, (sum, s) => sum + s.pings);
    final movingMin = _segments
        .where((s) => s.activity == 'driving' || s.activity == 'walking')
        .fold<int>(0, (sum, s) => sum + s.durationMin);
    final stationaryMin = _segments
        .where((s) => s.activity == 'stationary')
        .fold<int>(0, (sum, s) => sum + s.durationMin);

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              _SummaryChip(
                icon: Icons.schedule,
                label: _formatDuration(totalDuration),
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              _SummaryChip(
                icon: Icons.directions_car,
                label: '${_formatDuration(movingMin)} moving',
                color: AppColors.activityDriving,
              ),
              const SizedBox(width: AppSpacing.sm),
              _SummaryChip(
                icon: Icons.pause_circle_outline,
                label: '${_formatDuration(stationaryMin)} idle',
                color: AppColors.activityStationary,
              ),
              const Spacer(),
              Text(
                '$totalPings pings',
                style: AppTextStyles.caption,
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () {
                  _lastLoadedTechId = null;
                  final tech = ref.read(selectedTechProvider);
                  final date = ref.read(selectedDateProvider);
                  if (tech != null) {
                    _loadTimeline(tech.technicianId, DateFormat('yyyy-MM-dd').format(date));
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),

        // Timeline list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: _segments.length,
            itemBuilder: (context, index) {
              final segment = _segments[index];
              final isLast = index == _segments.length - 1;
              return _TimelineItem(
                segment: segment,
                isLast: isLast,
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final TimelineSegment segment;
  final bool isLast;

  const _TimelineItem({required this.segment, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(segment.activity);
    final icon = _activityIcon(segment.activity);
    final label = _activityLabel(segment.activity);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline track
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.5), AppColors.divider],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md, right: AppSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: AppDecorations.brandedCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.timelineTimeTitle.copyWith(color: color),
                      ),
                      const Spacer(),
                      if (segment.durationMin > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: AppDecorations.pillBadge(color),
                          child: Text(
                            _formatMin(segment.durationMin),
                            style: AppTextStyles.chipText.copyWith(color: color, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('hh:mm a').format(segment.startAt.toLocal())} — ${DateFormat('hh:mm a').format(segment.endAt.toLocal())}',
                        style: AppTextStyles.timelineDurationSubtitle,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (segment.battery != null) ...[
                        Icon(
                          segment.battery! < 20 ? Icons.battery_alert : Icons.battery_std,
                          size: 11,
                          color: segment.battery! < 20 ? AppColors.error : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${segment.battery}%',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: segment.battery! < 20 ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Icon(Icons.cell_tower, size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        '${segment.pings} pings',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _activityColor(String activity) {
    switch (activity) {
      case 'driving': return AppColors.activityDriving;
      case 'walking': return AppColors.activityWalking;
      case 'stationary': return AppColors.activityStationary;
      case 'moving': return AppColors.trackOnline;
      default: return AppColors.textHint;
    }
  }

  IconData _activityIcon(String activity) {
    switch (activity) {
      case 'driving': return Icons.directions_car;
      case 'walking': return Icons.directions_walk;
      case 'stationary': return Icons.location_on;
      case 'moving': return Icons.trending_up;
      default: return Icons.help_outline;
    }
  }

  String _activityLabel(String activity) {
    switch (activity) {
      case 'driving': return 'Driving';
      case 'walking': return 'Walking';
      case 'stationary': return 'Stationary';
      case 'moving': return 'Moving';
      default: return activity.isNotEmpty ? activity[0].toUpperCase() + activity.substring(1) : 'Unknown';
    }
  }

  String _formatMin(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

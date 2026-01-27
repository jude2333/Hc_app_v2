import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class TimeLinePage extends StatelessWidget {
  final WorkOrder workOrder;

  const TimeLinePage({Key? key, required this.workOrder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timelineData = workOrder.timeLine;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timeline, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Timeline',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                workOrder.patientName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: timelineData.isEmpty
          ? _buildEmptyState()
          : _buildTimeline(timelineData),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timeline_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Timeline Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity history will appear here',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> timelineData) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: timelineData.length,
      itemBuilder: (context, index) {
        final timeline = timelineData[index].toString();
        final parts = _formatTimeline(timeline);
        final isFirst = index == 0;
        final isLast = index == timelineData.length - 1;

        return _ModernTimelineItem(
          date: parts[0],
          author: parts[1],
          description: parts[2],
          isFirst: isFirst,
          isLast: isLast,
          index: index,
        );
      },
    );
  }

  List<String> _formatTimeline(String item) {
    final parts = item.split('|');
    if (parts.length >= 3) {
      return [
        parts[0].trim(),
        parts[1].trim(),
        parts[2].trim(),
      ];
    }
    return [item, '', ''];
  }
}

class _ModernTimelineItem extends StatelessWidget {
  final String date;
  final String author;
  final String description;
  final bool isFirst;
  final bool isLast;
  final int index;

  const _ModernTimelineItem({
    required this.date,
    required this.author,
    required this.description,
    required this.index,
    this.isFirst = false,
    this.isLast = false,
  });

  Color _getAccentColor() {
    final desc = description.toLowerCase();
    if (desc.contains('created')) return AppColors.success;
    if (desc.contains('assigned')) return AppColors.secondary;
    if (desc.contains('cancelled')) return AppColors.error;
    if (desc.contains('finished') || desc.contains('completed'))
      return AppColors.success;
    if (desc.contains('billed')) return Colors.green;
    return AppColors.primary;
  }

  IconData _getIcon() {
    final desc = description.toLowerCase();
    if (desc.contains('created')) return Icons.add_circle_outline;
    if (desc.contains('assigned')) return Icons.person_add_outlined;
    if (desc.contains('cancelled')) return Icons.cancel_outlined;
    if (desc.contains('finished') || desc.contains('completed'))
      return Icons.check_circle_outline;
    if (desc.contains('billed')) return Icons.receipt_outlined;
    if (desc.contains('delay')) return Icons.schedule_outlined;
    if (desc.contains('proforma')) return Icons.description_outlined;
    if (desc.contains('otp')) return Icons.verified_outlined;
    if (desc.contains('photo')) return Icons.camera_alt_outlined;
    return Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 16,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.3),
                          accentColor
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 2),
                  ),
                  child: Icon(
                    _getIcon(),
                    size: 16,
                    color: accentColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.3)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            description.isNotEmpty ? description : 'Activity',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          icon: Icons.calendar_today_outlined,
                          label: date,
                          color: AppColors.textSecondary,
                        ),
                        if (author.isNotEmpty)
                          _InfoChip(
                            icon: Icons.person_outline,
                            label: author,
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../data/tracking_repository.dart';
import '../providers/tracking_ui_providers.dart';

/// Daily analytics tab showing technician performance stats.
class AnalyticsTab extends ConsumerStatefulWidget {
  final String token;
  final int? tenantId;
  final DateTime? selectedDate; // Legacy prop, can be removed if strictly using Riverpod

  const AnalyticsTab({
    super.key,
    required this.token,
    this.tenantId,
    this.selectedDate,
  });

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  List<Map<String, dynamic>> _analytics = [];
  bool _loading = false;
  String? _error;
  String? _lastDate;

  Future<void> _loadAnalytics(String dateStr) async {
    if (dateStr == _lastDate) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = TrackingRepository(token: widget.token);
      final data = await repo.getDailyAnalytics(
        tenantId: widget.tenantId,
        date: dateStr,
      );
      
      if (mounted) {
        setState(() {
          _lastDate = dateStr;
          _analytics = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastDate = dateStr;
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Trigger data load when date changes (safe — only in build)
    if (dateStr != _lastDate && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAnalytics(dateStr);
      });
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.analytics, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Daily Analytics — ${DateFormat('MMM d, yyyy').format(selectedDate)}',
                style: AppTextStyles.h3,
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  _lastDate = null;
                  _loadAnalytics(DateFormat('yyyy-MM-dd').format(ref.read(selectedDateProvider)));
                },
                borderRadius: BorderRadius.circular(AppRadius.round),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _buildContent(selectedDate),
        ),
      ],
    );
  }

  Widget _buildContent(DateTime selectedDate) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text('Crunching numbers...', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error loading analytics', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              onPressed: () {
                _lastDate = null;
                _loadAnalytics(DateFormat('yyyy-MM-dd').format(ref.read(selectedDateProvider)));
              }, 
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_analytics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No data for ${DateFormat('MMMM d').format(selectedDate)}',
              style: AppTextStyles.h2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Analytics are computed at midnight for the previous day.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
    }

    // Summary row
    final totalDistance = _analytics.fold<double>(0, (sum, a) => sum + ((a['total_distance'] as num?)?.toDouble() ?? 0));
    final totalPings = _analytics.fold<int>(0, (sum, a) => sum + ((a['total_pings'] as num?)?.toInt() ?? 0));
    final totalVisits = _analytics.fold<int>(0, (sum, a) => sum + ((a['visits_count'] as num?)?.toInt() ?? 0));

    return Column(
      children: [
        // Summary KPI Cards
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _KpiCard(
                icon: Icons.people,
                label: 'Technicians',
                value: '${_analytics.length}',
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              _KpiCard(
                icon: Icons.route,
                label: 'Total Distance',
                value: '${totalDistance.toStringAsFixed(1)} km',
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.md),
              _KpiCard(
                icon: Icons.pin_drop,
                label: 'Total Pings',
                value: NumberFormat.compact().format(totalPings),
                color: Colors.purple,
              ),
              const SizedBox(width: AppSpacing.md),
              _KpiCard(
                icon: Icons.check_circle,
                label: 'Visits Done',
                value: '$totalVisits',
                color: AppColors.activityWalking,
              ),
            ],
          ),
        ),

        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Technician', style: AppTextStyles.tableHeader)),
              Expanded(flex: 2, child: Text('Distance', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Active', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Idle', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
              Expanded(flex: 1, child: Text('Visits', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('First / Last Ping', style: AppTextStyles.tableHeader, textAlign: TextAlign.center)),
            ],
          ),
        ),

        // Table rows
        Expanded(
          child: ListView.builder(
            itemCount: _analytics.length,
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemBuilder: (context, index) {
              final a = _analytics[index];
              final distance = ((a['total_distance'] as num?)?.toDouble() ?? 0);
              final activeH = ((a['active_hours'] as num?)?.toDouble() ?? 0);
              final idleH = ((a['idle_hours'] as num?)?.toDouble() ?? 0);
              final visits = (a['visits_count'] as num?)?.toInt() ?? 0;
              final firstPing = a['first_ping_at'] != null ? DateTime.tryParse(a['first_ping_at'].toString()) : null;
              final lastPing = a['last_ping_at'] != null ? DateTime.tryParse(a['last_ping_at'].toString()) : null;
              final name = a['technician_name']?.toString() ?? 'Tech #${a['technician_id']}';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: index.isEven ? AppColors.tableRowEven : AppColors.tableRowOdd,
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(name, style: AppTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${distance.toStringAsFixed(1)} km',
                        style: AppTextStyles.tableCell,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${activeH.toStringAsFixed(1)}h',
                          style: AppTextStyles.tableCell.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${idleH.toStringAsFixed(1)}h',
                        style: AppTextStyles.tableCell.copyWith(color: AppColors.trackIdle, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '$visits',
                        style: AppTextStyles.tableCell.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        firstPing != null
                            ? '${DateFormat('HH:mm').format(firstPing.toLocal())} — ${lastPing != null ? DateFormat('HH:mm').format(lastPing.toLocal()) : 'Now'}'
                            : '--',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: AppDecorations.brandedCard,
        child: Stack(
          children: [
            // Faint watermark icon in background
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(icon, size: 60, color: color.withValues(alpha: 0.05)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                Text(value, style: AppTextStyles.metricLarge.copyWith(color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

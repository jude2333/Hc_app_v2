import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../models/technician_metrics.dart';
import '../providers/technician_dashboard_providers.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/tech_dashboard_widgets.dart';

class TechWeeklyTab extends ConsumerStatefulWidget {
  const TechWeeklyTab({super.key});

  @override
  ConsumerState<TechWeeklyTab> createState() => _TechWeeklyTabState();
}

class _TechWeeklyTabState extends ConsumerState<TechWeeklyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(techWeeklyProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(techWeeklyProvider);
    final notifier = ref.read(techWeeklyProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          DashboardDateRangeHeader(
            title: 'Last 7 Days',
            subtitle: 'Performance Summary',
            onTap: () => notifier.loadData(),
          ),
          Expanded(
            child: state.when(
              initial: () => const DashboardSkeletonLoading(),
              loading: (_) => const DashboardSkeletonLoading(),
              loaded: (report) => _buildContent(report),
              error: (message) => DashboardEmptyState(
                message: message,
                onRetry: () => notifier.loadData(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TechnicianReport report) {
    final metrics = report.totals;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Overall completion rate for the week
          CompletionRateRing(
            finished: metrics.finished,
            assigned: metrics.assigned,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Summary cards
          Row(
            children: [
              DashboardMetricCard(
                title: 'ASSIGNED',
                value: metrics.assigned,
                color: Colors.blue,
              ),
              const SizedBox(width: AppSpacing.md),
              DashboardMetricCard(
                title: 'FINISHED',
                value: metrics.finished,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              DashboardMetricCard(
                title: 'PENDING',
                value: metrics.pending,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              DashboardMetricCard(
                title: 'CANCELLED',
                value: metrics.cancelled,
                color: AppColors.error,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Financial summary
          DashboardFinancialCard(
            title: 'TOTAL RECEIVED',
            value: metrics.totalReceived,
            color: Colors.indigo,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              DashboardMetricCard(
                title: 'CASH',
                value: metrics.cashCollected,
                color: Colors.teal,
                isMoney: true,
              ),
              const SizedBox(width: AppSpacing.md),
              DashboardMetricCard(
                title: 'GPAY',
                value: metrics.gpayCollected,
                color: AppColors.chartPurple,
                isMoney: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              DashboardMetricCard(
                title: 'HC CHARGES',
                value: metrics.hcCharges,
                color: AppColors.andersonBlue,
                isMoney: true,
              ),
              const SizedBox(width: AppSpacing.md),
              DashboardMetricCard(
                title: 'REMITTANCE DUE',
                value: metrics.remittancePending,
                color: Colors.deepOrange,
                isMoney: true,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),
          const DashboardSectionTitle('Case Trends'),
          const SizedBox(height: AppSpacing.sm),
          _buildCasesChart(report),

          const SizedBox(height: AppSpacing.xxl),
          const DashboardSectionTitle('Financial Trends'),
          const SizedBox(height: AppSpacing.sm),
          _buildFinancialChart(report),

          const SizedBox(height: AppSpacing.xxl),
          const DashboardSectionTitle('Daily Breakdown'),
          const SizedBox(height: AppSpacing.sm),
          _buildBreakdownTable(report),
        ],
      ),
    );
  }

  // ── Case status bar chart ──
  Widget _buildCasesChart(TechnicianReport report) {
    final colorScheme = Theme.of(context).colorScheme;
    final allValues = [
      ...report.chartAssigned,
      ...report.chartFinished,
      ...report.chartCancelled,
    ];
    final maxY = calculateMaxY(allValues);
    final interval = calculateInterval(maxY);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: buildBarTouchData(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= report.chartLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      report.chartLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(report.chartLabels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                buildGradientBar(
                  value: report.chartAssigned[i].toDouble(),
                  color: Colors.blue,
                  width: 10,
                ),
                buildGradientBar(
                  value: report.chartFinished[i].toDouble(),
                  color: AppColors.success,
                  width: 10,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Financial bar chart (Cash vs GPay) ──
  Widget _buildFinancialChart(TechnicianReport report) {
    final colorScheme = Theme.of(context).colorScheme;
    final allValues = [...report.chartCash, ...report.chartGpay];
    final maxY = calculateMaxY(allValues);
    final interval = calculateInterval(maxY);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: buildBarTouchData(isMoney: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  formatCompactNumber(value.toInt()),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= report.chartLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      report.chartLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(report.chartLabels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                buildGradientBar(
                  value: report.chartCash[i].toDouble(),
                  color: Colors.teal,
                  width: 10,
                ),
                buildGradientBar(
                  value: report.chartGpay[i].toDouble(),
                  color: AppColors.chartPurple,
                  width: 10,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Daily breakdown table ──
  Widget _buildBreakdownTable(TechnicianReport report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop/tablet: use existing table
        if (constraints.maxWidth >= 600) {
          return _buildDesktopTable(report);
        }
        // Mobile: compact card list
        return _buildMobileBreakdown(report);
      },
    );
  }

  Widget _buildDesktopTable(TechnicianReport report) {
    final tableData = report.rows.map((row) {
      return {
        'label': row.label,
        'assigned': row.metrics.assigned,
        'finished': row.metrics.finished,
        'pending': row.metrics.pending,
        'cancelled': row.metrics.cancelled,
        'received': row.metrics.totalReceived,
        'isTotal': row.isTotal,
      };
    }).toList();

    return DashboardDetailedTable(
      headers: const ['Day', 'Assigned', 'Done', 'Pending', 'Cancel', 'Received'],
      flexValues: const [3, 2, 2, 2, 2, 2],
      data: tableData,
      dataKeys: const ['label', 'assigned', 'finished', 'pending', 'cancelled', 'received'],
      minWidth: 500,
    );
  }

  Widget _buildMobileBreakdown(TechnicianReport report) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: report.rows.map((row) {
        final m = row.metrics;
        final isTotal = row.isTotal;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isTotal
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surface,
            borderRadius: AppRadius.xlAll,
            border: Border.all(
              color: isTotal
                  ? AppColors.gradientStart.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day label
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: isTotal
                      ? AppColors.gradientStart
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Status chips row
              Row(
                children: [
                  _buildChip('A', m.assigned, Colors.blue, colorScheme),
                  const SizedBox(width: 6),
                  _buildChip('F', m.finished, AppColors.success, colorScheme),
                  const SizedBox(width: 6),
                  _buildChip('P', m.pending, AppColors.primary, colorScheme),
                  const SizedBox(width: 6),
                  _buildChip('C', m.cancelled, AppColors.error, colorScheme),
                  const Spacer(),
                  // Received amount
                  Text(
                    Util.formatMoney(m.totalReceived),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isTotal
                          ? AppColors.gradientStart
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip(
      String label, int value, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

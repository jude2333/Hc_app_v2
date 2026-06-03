import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../models/dashboard_report.dart';
import '../providers/dashboard_providers.dart';
import '../providers/dashboard_state.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/report_chart.dart';
import '../widgets/report_table.dart';

class YearlyTab extends ConsumerStatefulWidget {
  const YearlyTab({super.key});

  @override
  ConsumerState<YearlyTab> createState() => _YearlyTabState();
}

class _YearlyTabState extends ConsumerState<YearlyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(yearlyReportProvider.notifier).loadAvailableYears();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(yearlyReportProvider);
    final notifier = ref.read(yearlyReportProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(notifier),
          Expanded(
            child: state.when(
              initial: () => const DashboardSkeletonLoading(),
              loading: (_) => const DashboardSkeletonLoading(),
              loaded: (report) => _buildContent(report, notifier),
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

  Widget _buildHeader(YearlyReportNotifier notifier) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notifier.monthwise ? "Monthly View" : "Yearly View",
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                notifier.monthwise
                    ? notifier.selectedYear.toString()
                    : "All Years",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (notifier.monthwise && notifier.availableYears.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: notifier.selectedYear,
                    underline: const SizedBox(),
                    dropdownColor: colorScheme.surface,
                    items: notifier.availableYears.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (year) {
                      if (year != null) notifier.selectYear(year);
                    },
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 12,
                        color: notifier.monthwise ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: notifier.monthwise
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Switch(
                      value: notifier.monthwise,
                      onChanged: notifier.toggleMonthwise,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                      thumbColor: WidgetStateProperty.all(AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DashboardReport report, YearlyReportNotifier notifier) {
    final chartTitle = notifier.monthwise ? "Monthly" : "Yearly";

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const DashboardSectionTitle("Detailed Report"),
          const SizedBox(height: 12),
          ReportDataTable(rows: report.rows, type: ReportType.yearly),
          const SizedBox(height: 24),
          DashboardSectionTitle("$chartTitle Case Trend"),
          const SizedBox(height: 12),
          ReportCasesChart(data: report.chartData),
          const SizedBox(height: 24),
          DashboardSectionTitle("$chartTitle Financial Trend"),
          const SizedBox(height: 12),
          ReportFinancialChart(data: report.financialChartData),
        ],
      ),
    );
  }
}

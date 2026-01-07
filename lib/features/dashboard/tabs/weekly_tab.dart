import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_report.dart';
import '../providers/dashboard_providers.dart';
import '../providers/dashboard_state.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/report_chart.dart';
import '../widgets/report_table.dart';

class WeeklyTab extends ConsumerStatefulWidget {
  const WeeklyTab({super.key});

  @override
  ConsumerState<WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends ConsumerState<WeeklyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(weeklyReportProvider.notifier).loadData();
    });
  }

  Future<void> _selectDateRange() async {
    final notifier = ref.read(weeklyReportProvider.notifier);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: notifier.startDate,
        end: notifier.endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.orange),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      notifier.selectDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(weeklyReportProvider);
    final notifier = ref.read(weeklyReportProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(notifier.startDate, notifier.endDate),
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

  Widget _buildHeader(DateTime startDate, DateTime endDate) {
    final subtitle =
        '${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';

    return DashboardDateRangeHeader(
      title: 'Weekly Report',
      subtitle: subtitle,
      onTap: _selectDateRange,
    );
  }

  Widget _buildContent(DashboardReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const DashboardSectionTitle("Detailed Report"),
          const SizedBox(height: 12),
          ReportDataTable(rows: report.rows, type: ReportType.weekly),
          const SizedBox(height: 24),
          const DashboardSectionTitle("Weekly Case Trend"),
          const SizedBox(height: 12),
          ReportCasesChart(data: report.chartData),
          const SizedBox(height: 24),
          const DashboardSectionTitle("Weekly Financial Trend"),
          const SizedBox(height: 12),
          ReportFinancialChart(data: report.financialChartData),
        ],
      ),
    );
  }
}

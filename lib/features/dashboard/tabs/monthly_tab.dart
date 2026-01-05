import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_report.dart';
import '../providers/dashboard_providers.dart';
import '../providers/dashboard_state.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/report_chart.dart';
import '../widgets/report_table.dart';

class MonthlyTab extends ConsumerStatefulWidget {
  const MonthlyTab({super.key});

  @override
  ConsumerState<MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends ConsumerState<MonthlyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(monthlyReportProvider.notifier).loadData();
    });
  }

  Future<void> _selectMonth() async {
    final notifier = ref.read(monthlyReportProvider.notifier);

    final picked = await showDatePicker(
      context: context,
      initialDate: notifier.selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
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
      notifier.selectMonth(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(monthlyReportProvider);
    final notifier = ref.read(monthlyReportProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(notifier.selectedMonth),
          Expanded(
            child: state.when(
              initial: () => const DashboardSkeletonLoading(),
              loading: (isFirst) => isFirst
                  ? const DashboardSkeletonLoading()
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.orange)),
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

  Widget _buildHeader(DateTime selectedMonth) {
    final monthName = DateFormat('MMMM yyyy').format(selectedMonth);

    return DashboardDateRangeHeader(
      title: 'Monthly Report',
      subtitle: monthName,
      onTap: _selectMonth,
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
          ReportDataTable(rows: report.rows, type: ReportType.monthly),
          const SizedBox(height: 24),
          const DashboardSectionTitle("Monthly Case Trend"),
          const SizedBox(height: 12),
          ReportCasesChart(data: report.chartData),
          const SizedBox(height: 24),
          const DashboardSectionTitle("Monthly Financial Trend"),
          const SizedBox(height: 12),
          ReportFinancialChart(data: report.financialChartData),
        ],
      ),
    );
  }
}

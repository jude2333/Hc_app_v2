import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import '../models/dashboard_report.dart';
import '../providers/dashboard_providers.dart';
import '../providers/dashboard_state.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/report_chart.dart';

class DailyTab extends ConsumerStatefulWidget {
  const DailyTab({super.key});

  @override
  ConsumerState<DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends ConsumerState<DailyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyReportProvider.notifier).loadData();
    });
  }

  Future<void> _selectDate() async {
    final notifier = ref.read(dailyReportProvider.notifier);

    final picked = await showDatePicker(
      context: context,
      initialDate: notifier.selectedDate,
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
      notifier.selectDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final state = ref.watch(dailyReportProvider);
    final notifier = ref.read(dailyReportProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(notifier.selectedDate),
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

  Widget _buildHeader(DateTime selectedDate) {
    return DashboardDateHeader(
      selectedDate: selectedDate,
      onTap: _selectDate,
    );
  }

  Widget _buildContent(DashboardReport report) {
    final metrics = report.totals;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const DashboardSectionTitle("Overview"),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                  "Assigned", metrics.assigned.toString(), Colors.blue),
              const SizedBox(width: 12),
              _buildMetricCard(
                  "Finished", metrics.finished.toString(), Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                  "Pending", metrics.pending.toString(), Colors.orange),
              const SizedBox(width: 12),
              _buildMetricCard(
                  "Cancelled", metrics.cancelled.toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          _buildFinancialCard(
              "Total Collection", metrics.collection, Colors.indigo),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                  "Received", Util.formatMoney(metrics.received), Colors.teal),
              const SizedBox(width: 12),
              _buildMetricCard(
                  "Credit", Util.formatMoney(metrics.credit), Colors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                  "B2B", Util.formatMoney(metrics.b2b), Colors.brown),
              const SizedBox(width: 12),
              _buildMetricCard(
                  "Trial", Util.formatMoney(metrics.trial), Colors.grey),
            ],
          ),
          const SizedBox(height: 20),
          const DashboardSectionTitle("Case Status"),
          const SizedBox(height: 8),
          DailyCasesChart(data: report.chartData),
          const SizedBox(height: 20),
          const DashboardSectionTitle("Financial Summary"),
          const SizedBox(height: 8),
          DailyFinancialChart(data: report.financialChartData),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
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
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Util.formatMoney(value),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wallet, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

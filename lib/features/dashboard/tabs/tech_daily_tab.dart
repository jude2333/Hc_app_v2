import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import '../models/technician_metrics.dart';
import '../providers/technician_dashboard_providers.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/tech_dashboard_widgets.dart';

class TechDailyTab extends ConsumerStatefulWidget {
  const TechDailyTab({super.key});

  @override
  ConsumerState<TechDailyTab> createState() => _TechDailyTabState();
}

class _TechDailyTabState extends ConsumerState<TechDailyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(techDailyProvider.notifier).loadData();
    });
  }

  Future<void> _selectDate() async {
    final notifier = ref.read(techDailyProvider.notifier);
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: notifier.selectedDate,
      // Limit to 7-day sync window
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
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

    final state = ref.watch(techDailyProvider);
    final notifier = ref.read(techDailyProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          DashboardDateHeader(
            selectedDate: notifier.selectedDate,
            onTap: _selectDate,
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

          // Completion Rate Ring
          CompletionRateRing(
            finished: metrics.finished,
            assigned: metrics.assigned,
          ),

          const SizedBox(height: AppSpacing.xl),
          const DashboardSectionTitle('Cases'),
          const SizedBox(height: AppSpacing.md),

          // Status cards — 2x2 grid
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
          const DashboardSectionTitle('Financial'),
          const SizedBox(height: AppSpacing.md),

          // Total Received — hero card
          DashboardFinancialCard(
            title: 'TOTAL RECEIVED',
            value: metrics.totalReceived,
            color: Colors.indigo,
          ),

          const SizedBox(height: AppSpacing.md),

          // Cash / GPay split
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

          // HC Charges / Remittance Pending
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/theme.dart';
import '../models/tech_analytics_models.dart';
import '../providers/tech_analytics_provider.dart';
import '../services/excel_export_service.dart';
import '../widgets/tech_analytics_widgets.dart';

class TechAnalyticsPage extends ConsumerStatefulWidget {
  const TechAnalyticsPage({super.key});

  @override
  ConsumerState<TechAnalyticsPage> createState() => _TechAnalyticsPageState();
}

class _TechAnalyticsPageState extends ConsumerState<TechAnalyticsPage> {
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(techAnalyticsProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(techAnalyticsProvider);
    final selectedRange = ref.watch(analyticsRangeProvider);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundSmoke,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 2,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: AppPadding.badge,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: AppRadius.lgAll,
          ),
          child: const Text(
            'Technician Analytics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          // Refresh
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () =>
                ref.read(techAnalyticsProvider.notifier).loadData(),
          ),
          // Export
          if (state.report != null && !state.isLoading)
            IconButton(
              tooltip: 'Export to Excel',
              icon: const Icon(Icons.file_download_outlined,
                  color: Color(0xFF217346)),
              onPressed: () => _exportToExcel(state.report!),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Range selector
          AnalyticsRangeSelector(
            selected: selectedRange,
            onChanged: (range) {
              ref.read(analyticsRangeProvider.notifier).state = range;
              ref.read(techAnalyticsProvider.notifier).loadData();
            },
            onCustomTap: () => _pickCustomRange(context),
          ),

          const SizedBox(height: 12),

          // Date range label
          if (state.report != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.date_range,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(state.report!.startDate)} — ${DateFormat('dd MMM yyyy').format(state.report!.endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (state.report!.technicians.isNotEmpty)
                    Text(
                      '${state.report!.overallTotals.totalOrders} orders • ${state.report!.technicians.length} technicians',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Body
          Expanded(child: _buildBody(state, isMobile)),
        ],
      ),
    );
  }

  Widget _buildBody(TechAnalyticsState state, bool isMobile) {
    if (state.isLoading) {
      if (isMobile) {
        return ListView(
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling during load
          children: [
            const AnalyticsAggregateCardSkeleton(),
            const SizedBox(height: 12),
            ...List.generate(5, (index) => const TechAnalyticsCardSkeleton()),
          ],
        );
      } else {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            children: const [
              AnalyticsAggregateCardSkeleton(),
              SizedBox(height: 12),
              Expanded(
                child: TechAnalyticsDesktopTableSkeleton(),
              ),
            ],
          ),
        );
      }
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 8),
            Text(state.errorMessage!,
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(techAnalyticsProvider.notifier).loadData(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final report = state.report;
    if (report == null || report.technicians.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 56, color: AppColors.border),
            SizedBox(height: 12),
            Text('No data for this period',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    if (isMobile) {
      return _buildMobileView(report);
    }
    return _buildDesktopView(report);
  }

  Widget _buildMobileView(AnalyticsReport report) {
    return ListView(
      children: [
        // Aggregates card
        AnalyticsAggregateCard(
          overall: report.overallTotals,
          rangeLabel: report.rangeLabel,
        ),
        const SizedBox(height: 8),
        // Technician cards
        ...report.technicians.asMap().entries.map((entry) {
          final index = entry.key;
          final tech = entry.value;
          return TechAnalyticsCard(
            tech: tech,
            isExpanded: _expandedIndices.contains(index),
            onTap: () {
              setState(() {
                if (_expandedIndices.contains(index)) {
                  _expandedIndices.remove(index);
                } else {
                  _expandedIndices.add(index);
                }
              });
            },
            onExport: () => _exportTechToExcel(tech, report),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDesktopView(AnalyticsReport report) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: [
          // Aggregates card
          AnalyticsAggregateCard(
            overall: report.overallTotals,
            rangeLabel: report.rangeLabel,
          ),
          const SizedBox(height: 12),
          // Desktop table
          Expanded(
            child: TechAnalyticsDesktopTable(
              technicians: report.technicians,
              onExportTech: (tech) => _exportTechToExcel(tech, report),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      helpText: 'Select date range for analytics',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      ref.read(analyticsCustomStartProvider.notifier).state = picked.start;
      ref.read(analyticsCustomEndProvider.notifier).state = picked.end;
      ref.read(analyticsRangeProvider.notifier).state = AnalyticsRange.custom;
      ref.read(techAnalyticsProvider.notifier).loadData();
    }
  }

  Future<void> _exportToExcel(AnalyticsReport report) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Generating Excel report...'),
            ],
          ),
          backgroundColor: Color(0xFF217346),
          duration: Duration(seconds: 2),
        ),
      );

      await ExcelExportService.exportReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text('Excel report exported successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportTechToExcel(
      TechAnalytics tech, AnalyticsReport report) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Generating report...'),
            ],
          ),
          backgroundColor: const Color(0xFF217346),
          duration: const Duration(seconds: 2),
        ),
      );

      await ExcelExportService.exportTechnicianReport(tech, report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 12),
                Text('Report exported successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

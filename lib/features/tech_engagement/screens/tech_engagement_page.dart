import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/providers/tech_engagement_provider.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/widgets/tech_desktop_table.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/widgets/tech_mobile_view.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/widgets/tech_shared_widgets.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class TechEngagementPage extends ConsumerStatefulWidget {
  const TechEngagementPage({super.key});

  @override
  ConsumerState<TechEngagementPage> createState() => _TechEngagementPageState();
}

class _TechEngagementPageState extends ConsumerState<TechEngagementPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(techEngagementProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(techEngagementProvider);
    final notifier = ref.read(techEngagementProvider.notifier);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        surfaceTintColor: Theme.of(context).colorScheme.surface,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Technician Engagements',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            onPressed: () => notifier.loadData(),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            _buildControlsRow(state, notifier, isMobile),
            const SizedBox(height: 12),
            if (!state.isLoading)
              _buildAggregatesCard(state.aggregates, isMobile),
            const SizedBox(height: 12),
            _buildSearchBar(notifier),
            const SizedBox(height: 12),
            Expanded(
              child: isMobile
                  ? TechMobileView(
                      techList: state.filteredList,
                      isLoading: state.isLoading,
                    )
                  : TechDesktopTable(
                      techList: state.filteredList,
                      isLoading: state.isLoading,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow(TechEngagementState state,
      TechEngagementNotifier notifier, bool isMobile) {
    return Row(
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              helpText: state.isMonthWise ? "SELECT MONTH" : "SELECT DATE",
            );
            if (picked != null) notifier.setDate(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  state.isMonthWise
                      ? DateFormat('yyyy-MM').format(state.selectedDate)
                      : DateFormat('yyyy-MM-dd').format(state.selectedDate),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isMobile ? 8 : 16),
        Row(
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: state.isMonthWise,
                onChanged: (val) => notifier.toggleMonthWise(val),
                activeColor: Colors.orange,
              ),
            ),
            Text(
              isMobile ? "Month" : "Month Wise",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAggregatesCard(AggregateSummary agg, bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : const Color(0xFF2196F3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Text(
              "Aggregates",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                AggCell("Assigned", "${agg.totalAssigned}"),
                const SizedBox(width: 16),
                AggCell("Cancelled", "${agg.totalCancelled}",
                    color: Colors.red),
                const SizedBox(width: 16),
                AggCell("Finished", "${agg.totalFinished}",
                    color: Colors.green),
                const SizedBox(width: 16),
                AggCell("Pending", "${agg.totalPending}", color: Colors.orange),
                const SizedBox(width: 16),
                AggCell("Cash", "${agg.totalCash.toInt()}"),
                const SizedBox(width: 16),
                AggCell("GPay", "${agg.totalGpay.toInt()}"),
                const SizedBox(width: 16),
                AggCell("HC", "${agg.totalHcCharges.toInt()}"),
                const SizedBox(width: 16),
                AggCell("Collected", "${agg.totalCollected.toInt()}"),
                const SizedBox(width: 16),
                AggCell("Received", "${agg.totalReceived.toInt()}",
                    color: Colors.blue),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Text(
                  "Total Cases Excluding Glucose(PP)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${agg.totalAccounted}",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(TechEngagementNotifier notifier) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: "Search technician...",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: notifier.search,
      ),
    );
  }
}

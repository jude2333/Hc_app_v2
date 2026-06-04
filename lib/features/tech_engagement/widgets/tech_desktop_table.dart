import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/providers/tech_engagement_provider.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/widgets/tech_patient_list.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/widgets/tech_shared_widgets.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class TechDesktopTable extends StatelessWidget {
  final List<TechSummary> techList;
  final bool isLoading;

  const TechDesktopTable({
    super.key,
    required this.techList,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildTableHeader(context),
          Expanded(
            child: isLoading
                ? _buildSkeletonLoading(context)
                : ListView.separated(
                    itemCount: techList.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: isDark ? AppColors.darkDivider : Colors.black12),
                    itemBuilder: (context, index) {
                      return TechDesktopRow(summary: techList[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor = isDark ? AppColors.darkBorder : Colors.grey.shade200;

    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkDivider : Colors.grey.shade200)),
          ),
          child: Row(
            children: List.generate(
                11,
                (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 14,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ))
              ..add(const SizedBox(width: 32)),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          TechHeaderCell("Technician", flex: 1),
          TechHeaderCell("Assigned", flex: 1),
          TechHeaderCell("Cancelled", flex: 1),
          TechHeaderCell("Finished", flex: 1),
          TechHeaderCell("Pending", flex: 1),
          TechHeaderCell("Appt Till", flex: 1),
          TechHeaderCell("Cash", flex: 1),
          TechHeaderCell("GPay", flex: 1),
          TechHeaderCell("HC", flex: 1),
          TechHeaderCell("Total", flex: 1),
          TechHeaderCell("Received", flex: 1),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

class TechDesktopRow extends StatefulWidget {
  final TechSummary summary;
  const TechDesktopRow({super.key, required this.summary});

  @override
  State<TechDesktopRow> createState() => _TechDesktopRowState();
}

class _TechDesktopRowState extends State<TechDesktopRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    if (s.assigned == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          hoverColor: isDark ? AppColors.darkSurfaceAlt : Colors.grey.shade100,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _expanded
                  ? (isDark ? AppColors.darkSurfaceAlt : Colors.orange.shade50)
                  : (isDark ? colorScheme.surface : Colors.white),
            ),
            child: Row(
              children: [
                TechDataCell(s.name, flex: 1, bold: true),
                TechDataCell("${s.assigned}", flex: 1),
                TechDataCell("${s.cancelled}", flex: 1, color: Colors.red),
                TechDataCell("${s.finished}", flex: 1, color: Colors.green),
                TechDataCell("${s.pending}", flex: 1, color: Colors.orange),
                TechDataCell(s.timeTill, flex: 1),
                TechDataCell("${s.cash.toInt()}", flex: 1),
                TechDataCell("${s.gpay.toInt()}", flex: 1),
                TechDataCell("${s.hcCharges.toInt()}", flex: 1),
                TechDataCell("${s.totalAmount.toInt()}", flex: 1),
                TechDataCell("${s.amountCollected.toInt()}",
                    flex: 1, color: Colors.blue),
                SizedBox(
                  width: 32,
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) TechPatientList(orders: widget.summary.orders),
      ],
    );
  }
}

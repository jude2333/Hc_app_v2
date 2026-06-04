import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/providers/tech_engagement_provider.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/widgets/tech_patient_list.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/theme/app_spacing.dart';

class TechMobileView extends StatelessWidget {
  final List<TechSummary> techList;
  final bool isLoading;

  const TechMobileView({
    super.key,
    required this.techList,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeletonLoading(context);
    }

    if (techList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No technicians found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: techList.length,
      itemBuilder: (context, index) {
        return TechMobileCard(summary: techList[index]);
      },
    );
  }

  Widget _buildSkeletonLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final skeletonColor = isDark ? AppColors.darkBorder : Colors.grey.shade200;
    final skeletonColorAlt =
        isDark ? AppColors.darkSurfaceAlt : Colors.grey.shade100;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
            side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(
                      3,
                      (i) => Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 20,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: skeletonColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 12,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: skeletonColorAlt,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          )),
                ),
                const SizedBox(height: 12),
                Divider(
                    height: 1,
                    color:
                        isDark ? AppColors.darkDivider : Colors.grey.shade200),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 10, width: 50, color: skeletonColorAlt),
                        const SizedBox(height: 4),
                        Container(
                            height: 16,
                            width: 70,
                            decoration: BoxDecoration(
                              color: skeletonColor,
                              borderRadius: BorderRadius.circular(4),
                            )),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 10, width: 40, color: skeletonColorAlt),
                        const SizedBox(height: 4),
                        Container(
                            height: 16,
                            width: 60,
                            decoration: BoxDecoration(
                              color: skeletonColor,
                              borderRadius: BorderRadius.circular(4),
                            )),
                      ],
                    ),
                    Icon(Icons.keyboard_arrow_down,
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade300),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TechMobileCard extends StatefulWidget {
  final TechSummary summary;
  const TechMobileCard({super.key, required this.summary});

  @override
  State<TechMobileCard> createState() => _TechMobileCardState();
}

class _TechMobileCardState extends State<TechMobileCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(
          color: _isExpanded
              ? Colors.orange
              : (isDark ? AppColors.darkBorder : AppColors.divider),
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${s.assigned} assigned",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MobileStatCell(
                          "Finished", "${s.finished}", Colors.green),
                      _MobileStatCell("Pending", "${s.pending}", Colors.orange),
                      _MobileStatCell(
                          "Cancelled", "${s.cancelled}", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                      height: 1,
                      color: isDark
                          ? AppColors.darkDivider
                          : Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Collected",
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textHint)),
                          Text("₹${s.amountCollected.toInt()}",
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Total",
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textHint)),
                          Text("₹${s.totalAmount.toInt()}",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface)),
                        ],
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.textHint,
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            TechPatientList(orders: s.orders),
          ]
        ],
      ),
    );
  }
}

class _MobileStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MobileStatCell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

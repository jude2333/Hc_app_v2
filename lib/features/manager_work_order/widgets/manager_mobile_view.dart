import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import '../widgets/manager_expanded_content.dart';
import '../widgets/manager_actions.dart';
import 'package:anderson_crm_flutter/features/theme/app_spacing.dart';

class ManagerMobileView extends ConsumerWidget {
  final List<WorkOrder> workOrders;
  final String searchQuery;
  final Function(String) onSearchChanged;

  const ManagerMobileView({
    super.key,
    required this.workOrders,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter logic moved to provider for better performance
    final filtered = workOrders;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search patients...',
              prefixIcon: Icon(Icons.search, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                // borderRadius: BorderRadius.circular(8),
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: onSearchChanged,
          ),
        ),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} work orders',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        // Work order cards
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _MobileWorkOrderCard(
                      workOrder: filtered[index],
                      index: index + 1,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Work Orders Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or date',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual work order card for mobile
class _MobileWorkOrderCard extends StatefulWidget {
  final WorkOrder workOrder;
  final int index;

  const _MobileWorkOrderCard({
    required this.workOrder,
    required this.index,
  });

  @override
  State<_MobileWorkOrderCard> createState() => _MobileWorkOrderCardState();
}

class _MobileWorkOrderCardState extends State<_MobileWorkOrderCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        // borderRadius: BorderRadius.circular(8),
        borderRadius: AppRadius.mdAll,
        side: BorderSide(
          color: _isExpanded ? AppColors.primary : AppColors.divider,
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main card content (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: Index + Name + Expand icon
                  Row(
                    children: [
                      // Index badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.index}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Patient name + badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    wo.patientName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${wo.gender} • ${wo.age} • ${wo.mobile}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Expand icon
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Status chips row
                  Row(
                    children: [
                      StatusChip(status: wo.status),
                      const SizedBox(width: 8),
                      ServerChip(status: wo.serverStatus),
                      const Spacer(),
                      // Visit time
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              wo.visitTime,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Assigned to row
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          wo.assignedTo.isNotEmpty
                              ? wo.assignedTo
                              : 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: wo.assignedTo.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                            fontStyle: wo.assignedTo.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content - conditionally rendered for best performance
          if (_isExpanded)
            RepaintBoundary(
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.divider),
                  // Actions row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: ManagerActions(workOrder: wo),
                  ),
                  Divider(height: 1, color: AppColors.divider),
                  // Expanded details
                  ManagerExpandedContent(workOrder: wo),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

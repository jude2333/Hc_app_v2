import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../providers/search_provider.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/features/manager_work_order/widgets/manager_expanded_content.dart';

class SearchMobileView extends ConsumerWidget {
  final List<Map<String, dynamic>> results;

  const SearchMobileView({super.key, required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedRows = ref.watch(expandedRowsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await ref.read(searchProvider.notifier).search();
      },
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.md),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          final docId = item['_id']?.toString() ?? index.toString();
          final isExpanded = expandedRows.contains(docId);

          return RepaintBoundary(
            key: ValueKey(docId),
            child: _SearchResultCard(
              item: item,
              index: index + 1,
              isExpanded: isExpanded,
              onToggle: () => _toggleExpanded(ref, docId),
            ),
          );
        },
      ),
    );
  }

  void _toggleExpanded(WidgetRef ref, String docId) {
    final current = ref.read(expandedRowsProvider);
    final updated = Set<String>.from(current);
    if (updated.contains(docId)) {
      updated.remove(docId);
    } else {
      updated.add(docId);
    }
    ref.read(expandedRowsProvider.notifier).state = updated;
  }
}

class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _SearchResultCard({
    required this.item,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Unknown';
    final mobile = item['mobile']?.toString() ?? '';
    final date = item['appointment_date']?.toString() ?? '';
    final time = item['appointment_time']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final serverStatus = item['server_status']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(
          color: isExpanded
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.divider),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: isExpanded
                ? const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  )
                : AppRadius.mdAll,
            child: Padding(
              padding: AppPadding.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.primaryLight,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Center(
                          child: Text(
                            '$index',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NameWithBadges.raw(
                          name: name,
                          flags: NameWithBadges.extractFlagsFromMap(item),
                          layout: BadgeLayout.column,
                          nameStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.content_copy,
                          size: AppSizes.iconSm - 2,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => _copyWorkOrder(context),
                        tooltip: 'Copy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.phone,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textHint),
                      SizedBox(width: AppSpacing.xs),
                      CopyableText(
                        mobile,
                        isPhoneNumber: true,
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Icon(Icons.calendar_today,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textHint),
                      SizedBox(width: AppSpacing.xs),
                      CopyableText(
                        '$date $time',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      StatusChip(status: status),
                      SizedBox(width: AppSpacing.sm),
                      ServerChip(status: serverStatus),
                      if (item['assigned_to'] != null) ...[
                        SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: CopyableText(
                            '→ ${item['assigned_to']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.divider,
            ),
            ManagerExpandedContent(workOrder: WorkOrder.fromDocMap(item)),
          ],
        ],
      ),
    );
  }

  void _copyWorkOrder(BuildContext context) {
    try {
      final workOrder = WorkOrder.fromDocMap(item);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddWorkOrderPage(copyFrom: workOrder),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying work order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../providers/search_provider.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/features/manager_work_order/widgets/manager_expanded_content.dart';

class SearchDesktopTable extends ConsumerWidget {
  final List<Map<String, dynamic>> results;

  const SearchDesktopTable({super.key, required this.results});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortCol = ref.watch(sortColumnProvider);
    final sortAsc = ref.watch(sortAscendingProvider);

    List<Map<String, dynamic>> sorted = List.from(results);
    sorted.sort((a, b) {
      int cmp = 0;
      switch (sortCol) {
        case 'name':
          cmp = (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString());
          break;
        case 'status':
          cmp = (a['status'] ?? '')
              .toString()
              .compareTo((b['status'] ?? '').toString());
          break;
        case 'date':
        default:
          cmp = (a['appointment_date'] ?? '')
              .toString()
              .compareTo((b['appointment_date'] ?? '').toString());
          if (cmp == 0) {
            cmp = (a['appointment_time'] ?? '')
                .toString()
                .compareTo((b['appointment_time'] ?? '').toString());
          }
          break;
      }
      return sortAsc ? cmp : -cmp;
    });

    void handleSort(String sortKey) {
      if (sortCol == sortKey) {
        ref.read(sortAscendingProvider.notifier).state = !sortAsc;
      } else {
        ref.read(sortColumnProvider.notifier).state = sortKey;
        ref.read(sortAscendingProvider.notifier).state = true;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: AppSizes.cardElevation,
      color: colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          Container(
            padding: AppPadding.customTable,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.primaryLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.tableBorder,
                    width: 1),
              ),
            ),
            child: Row(
              children: [
                const HeaderCell('No', flex: 1),
                SortableHeader(
                  label: 'Name',
                  sortKey: 'name',
                  flex: 4,
                  currentSortColumn: sortCol,
                  isAscending: sortAsc,
                  onSort: handleSort,
                ),
                const HeaderCell('Gender', flex: 2),
                const HeaderCell('Age', flex: 1),
                const HeaderCell('Mobile', flex: 3),
                SortableHeader(
                  label: 'Date',
                  sortKey: 'date',
                  flex: 3,
                  currentSortColumn: sortCol,
                  isAscending: sortAsc,
                  onSort: handleSort,
                ),
                const HeaderCell('Time', flex: 2),
                SortableHeader(
                  label: 'Status',
                  sortKey: 'status',
                  flex: 3,
                  currentSortColumn: sortCol,
                  isAscending: sortAsc,
                  onSort: handleSort,
                ),
                const HeaderCell('Server Status', flex: 3),
                const HeaderCell('Assigned To', flex: 4),
                const HeaderCell('Actions', flex: 2),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 40, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text('No Results Found',
                            style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : DesktopSelectionArea(
                    child: ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          color: isDark ? AppColors.darkBorder : AppColors.divider,
                        ),
                        itemBuilder: (context, index) {
                          final item = sorted[index];
                          return RepaintBoundary(
                            key: ValueKey(item['_id'] ?? index),
                            child:
                                _SearchTableRow(item: item, index: index + 1),
                          );
                        },
                      ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchTableRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final int index;

  const _SearchTableRow({required this.item, required this.index});

  @override
  ConsumerState<_SearchTableRow> createState() => _SearchTableRowState();
}

class _SearchTableRowState extends ConsumerState<_SearchTableRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          hoverColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.tableBorder)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 2,
              ),
              child: Row(
                children: [
                  _buildCell('${widget.index}', flex: 1),
                  Expanded(
                    flex: 4,
                    child: NameWithBadges.raw(
                      name: item['name']?.toString() ?? '',
                      flags: NameWithBadges.extractFlagsFromMap(item),
                      layout: BadgeLayout.row,
                    ),
                  ),
                  _buildCell('${item['gender'] ?? ''}', flex: 2),
                  _buildCell('${item['age'] ?? ''}', flex: 1),
                  _buildCell('${item['mobile'] ?? ''}', flex: 3,
                      isPhoneNumber: true),
                  _buildCell('${item['appointment_date'] ?? ''}', flex: 3),
                  _buildCell('${item['appointment_time'] ?? ''}', flex: 2),
                  SelectionContainer.disabled(
                    child: Expanded(
                      flex: 3,
                      child: StatusChip(
                          status: item['status']?.toString() ?? ''),
                    ),
                  ),
                  SelectionContainer.disabled(
                    child: Expanded(
                      flex: 3,
                      child: ServerChip(
                          status: item['server_status']?.toString() ?? ''),
                    ),
                  ),
                  _buildCell('${item['assigned_to'] ?? ''}', flex: 4),
                  SelectionContainer.disabled(
                    child: Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.content_copy,
                                size: AppSizes.iconSm - 2,
                                color: AppColors.textHint),
                            onPressed: () => _copyWorkOrder(context),
                            tooltip: 'Copy',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SelectionContainer.disabled(
                    child: SizedBox(
                      width: 40,
                      child: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: AppSizes.iconSm - 2,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          ManagerExpandedContent(workOrder: WorkOrder.fromDocMap(widget.item)),
      ],
    );
  }

  Widget _buildCell(String text,
      {required int flex, bool isPhoneNumber = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: AppPadding.sm,
        child: CopyableText(text,
            overflow: TextOverflow.ellipsis, isPhoneNumber: isPhoneNumber),
      ),
    );
  }

  void _copyWorkOrder(BuildContext context) {
    try {
      final workOrder = WorkOrder.fromDocMap(widget.item);
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

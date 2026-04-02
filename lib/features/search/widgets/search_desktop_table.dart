import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../providers/search_provider.dart';
import 'search_expanded_content.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

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

    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.tableBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                const _HeaderCell('No', flex: 1),
                _SortableHeader(
                  label: 'Name',
                  sortKey: 'name',
                  flex: 4,
                  currentSortColumn: sortCol,
                  isAscending: sortAsc,
                  onSort: handleSort,
                ),
                const _HeaderCell('Gender', flex: 2),
                const _HeaderCell('Age', flex: 1),
                const _HeaderCell('Mobile', flex: 3),
                _SortableHeader(
                  label: 'Date',
                  sortKey: 'date',
                  flex: 3,
                  currentSortColumn: sortCol,
                  isAscending: sortAsc,
                  onSort: handleSort,
                ),
                const _HeaderCell('Time', flex: 2),
                _SortableHeader(
                  label: 'Status',
                  sortKey: 'status',
                  flex: 3,
                  currentSortColumn: sortCol,
                  isAscending: sortAsc,
                  onSort: handleSort,
                ),
                const _HeaderCell('Server Status', flex: 3),
                const _HeaderCell('Assigned To', flex: 4),
                const _HeaderCell('Actions', flex: 2),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: sorted.length,
              separatorBuilder: (ctx, i) =>
                  Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final item = sorted[index];
                return RepaintBoundary(
                  key: ValueKey(item['_id'] ?? index),
                  child: _SearchTableRow(item: item, index: index + 1),
                );
              },
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          hoverColor: AppColors.surfaceAlt,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  _buildCell('${widget.index}', flex: 1),
                  Expanded(
                    flex: 4,
                    child: _NameWithBadges(item: item),
                  ),
                  _buildCell('${item['gender'] ?? ''}', flex: 2),
                  _buildCell('${item['age'] ?? ''}', flex: 1),
                  _buildCell('${item['mobile'] ?? ''}', flex: 3),
                  _buildCell('${item['appointment_date'] ?? ''}', flex: 3),
                  _buildCell('${item['appointment_time'] ?? ''}', flex: 2),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusChip(status: '${item['status'] ?? ''}'),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child:
                          _ServerChip(status: '${item['server_status'] ?? ''}'),
                    ),
                  ),
                  _buildCell('${item['assigned_to'] ?? ''}', flex: 4),
                  Expanded(
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
                  SizedBox(
                    width: 40,
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: AppSizes.iconSm - 2,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded) SearchExpandedContent(item: item),
      ],
    );
  }

  Widget _buildCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Text(text, overflow: TextOverflow.ellipsis),
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

class _NameWithBadges extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NameWithBadges({required this.item});

  @override
  Widget build(BuildContext context) {
    final badges = <String>[];
    final urgentVal = item['urgent'];
    if (urgentVal == true || urgentVal == 1) badges.add('Urgent');
    final vipVal = item['vip_client'];
    if (vipVal == true || vipVal == 1) badges.add('VIP');
    if (item['credit'] == 1) badges.add('Credit');
    if (item['credit'] == 2) badges.add('Trial');
    final b2bId = int.tryParse(item['b2b_client_id']?.toString() ?? '0') ?? 0;
    if (b2bId > 0) badges.add('B2B');
    final cghsVal = item['cghs_client'];
    if (cghsVal == true || cghsVal == 1) badges.add('CGHS');

    return Row(
      children: [
        Flexible(
          child: Text(
            '${item['name'] ?? ''}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badges.isNotEmpty) ...[
          SizedBox(width: AppSpacing.xs),
          ...badges.map((b) {
            final isCghs = b == 'CGHS';
            final color = isCghs ? Colors.blue : AppColors.error;
            return Container(
              margin: EdgeInsets.only(right: 2),
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(b,
                  style: AppTextStyles.nameBadges.copyWith(color: color)),
            );
          }),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _getColor() {
    final s = status.toLowerCase();
    if (s.startsWith('un')) return AppColors.error;
    if (s == 'assigned') return AppColors.secondary;
    if (s == 'cancelled') return AppColors.textHint;
    if (s == 'finished') return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.custom,
      decoration: BoxDecoration(
        border: Border.all(color: _getColor()),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        status.isEmpty ? 'N/A' : status,
        style: TextStyle(fontSize: 11, color: _getColor()),
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  final String status;
  const _ServerChip({required this.status});

  Color _getColor() {
    final s = status.toLowerCase();
    if (s == 'billed') return AppColors.success;
    if (s == 'unbilled' || s == 'received') return AppColors.error;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final displayStatus = status == 'Received' ? 'Unbilled' : status;
    return Container(
      padding: AppPadding.custom,
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.15),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        displayStatus.isEmpty ? 'N/A' : displayStatus,
        style: TextStyle(fontSize: 12, color: _getColor()),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final String sortKey;
  final int flex;
  final String currentSortColumn;
  final bool isAscending;
  final void Function(String) onSort;

  const _SortableHeader({
    required this.label,
    required this.sortKey,
    required this.flex,
    required this.currentSortColumn,
    required this.isAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentSortColumn == sortKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(sortKey),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              if (isActive)
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

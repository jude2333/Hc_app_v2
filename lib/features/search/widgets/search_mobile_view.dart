import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../providers/search_provider.dart';
import 'search_expanded_content.dart';

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
    final name = item['name'] ?? 'Unknown';
    final mobile = item['mobile'] ?? '';
    final date = item['appointment_date'] ?? '';
    final time = item['appointment_time'] ?? '';
    final status = item['status'] ?? '';
    final serverStatus = item['server_status'] ?? '';

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: isExpanded
                ? BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  )
                : AppRadius.mdAll,
            child: Container(
              padding: AppPadding.card,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surface,
                    AppColors.primaryLight.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: isExpanded
                    ? BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      )
                    : AppRadius.mdAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.xsAll,
                        ),
                        child: Text(
                          '$index',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            _buildBadges(),
                          ],
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
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: AppColors.textHint),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        mobile,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Icon(Icons.calendar_today,
                          size: 14, color: AppColors.textHint),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        '$date $time',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _StatusChip(status: status),
                      SizedBox(width: AppSpacing.sm),
                      _ServerChip(status: serverStatus),
                      if (item['assigned_to'] != null) ...[
                        SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            '→ ${item['assigned_to']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
          if (isExpanded) SearchExpandedContent(item: item),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    final badges = <String>[];
    if (item['urgent'] == true) badges.add('Urgent');
    if (item['vip_client'] == true) badges.add('VIP');
    if (item['credit'] == 1) badges.add('Credit');
    if (item['credit'] == 2) badges.add('Trial');
    if (item['b2b_client_id'] != null) badges.add('B2B');

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      children: badges.map((badge) {
        return Container(
          margin: EdgeInsets.only(top: 2),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.error, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: TextStyle(fontSize: 9, color: AppColors.error),
          ),
        );
      }).toList(),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: _getColor()),
        borderRadius: BorderRadius.circular(12),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus.isEmpty ? 'N/A' : displayStatus,
        style: TextStyle(fontSize: 11, color: _getColor()),
      ),
    );
  }
}

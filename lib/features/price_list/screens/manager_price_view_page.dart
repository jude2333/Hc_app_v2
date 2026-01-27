import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:anderson_crm_flutter/features/price_list/price_list.dart';
import 'add_edit_price_dialog.dart';
import 'history_sheet.dart';

import '../../core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/theme/app_spacing.dart';

class ManagerPriceViewPage extends ConsumerStatefulWidget {
  const ManagerPriceViewPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ManagerPriceViewPage> createState() =>
      _ManagerPriceViewPageState();
}

class _ManagerPriceViewPageState extends ConsumerState<ManagerPriceViewPage> {
  final _searchController = TextEditingController();

  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(priceListProvider.notifier).loadComboData();
      ref.read(priceListProvider.notifier).search("");
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == query && mounted) {
        ref.read(priceListProvider.notifier).search(query);
      }
    });
  }

  void _openAddDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AddEditPriceDialog());
  }

  void _openEditDialog(PriceListItem item) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddEditPriceDialog(existingItem: item));
  }

  void _confirmDelete(PriceListItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Confirm Delete', style: TextStyle(color: Colors.red)),
        content: Text('Do you want to delete: ${item.investName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final res =
                  await ref.read(priceListProvider.notifier).deleteTest(item);
              if (mounted) {
                if (res == "OK") {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Deleted Successfully")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showHistory() {
    ref.read(priceListProvider.notifier).loadGlobalHistory();
    final screenWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxWidth: screenWidth < 800 ? screenWidth : screenWidth * 0.95,
          minWidth: screenWidth < 800 ? screenWidth : 800,
        ),
        builder: (_) => const HistorySheet());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceListProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(16)),
              child: const Text('Price List',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search (Name, Dept, >500)',
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade100)),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: _openAddDialog,
              tooltip: 'Add Test'),
          IconButton(
              icon: const Icon(Icons.history, color: Colors.grey),
              onPressed: _showHistory,
              tooltip: 'History'),
          IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: state.isLoading && state.items.isEmpty
          ? _buildSkeletonLoading(isMobile)
          : isMobile
              ? ManagerPriceMobileView(
                  items: state.items,
                  formatter: _currencyFormatter,
                  onEdit: _openEditDialog,
                  onDelete: _confirmDelete,
                )
              : _VirtualPriceTable(
                  items: state.items,
                  formatter: _currencyFormatter,
                  onEdit: _openEditDialog,
                  onDelete: _confirmDelete,
                ),
    );
  }

  Widget _buildSkeletonLoading(bool isMobile) {
    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 8,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4)))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [
                    Container(
                        width: 40, height: 10, color: Colors.grey.shade100),
                    const SizedBox(height: 4),
                    Container(
                        width: 60,
                        height: 16,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                  ]),
                  Column(children: [
                    Container(
                        width: 30, height: 10, color: Colors.grey.shade100),
                    const SizedBox(height: 4),
                    Container(
                        width: 50,
                        height: 14,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                  ]),
                  Column(children: [
                    Container(
                        width: 35, height: 10, color: Colors.grey.shade100),
                    const SizedBox(height: 4),
                    Container(
                        width: 50,
                        height: 14,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4))),
                  ]),
                  Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade300),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
              ),
              child: Row(
                children: List.generate(
                    6,
                    (i) => Expanded(
                          flex: i == 1 ? 3 : (i == 0 ? 2 : 1),
                          child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 14,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4))),
                        )),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 10,
                itemBuilder: (context, index) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200))),
                  child: Row(
                    children: List.generate(
                        6,
                        (i) => Expanded(
                              flex: i == 1 ? 3 : (i == 0 ? 2 : 1),
                              child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4))),
                            )),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VirtualPriceTable extends StatelessWidget {
  final List<PriceListItem> items;
  final NumberFormat formatter;
  final Function(PriceListItem) onEdit;
  final Function(PriceListItem) onDelete;

  const _VirtualPriceTable({
    required this.items,
    required this.formatter,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('No items found', style: TextStyle(color: Colors.grey)));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  FlexHeaderCell('Department', flex: 2),
                  FlexHeaderCell('Investigation', flex: 3),
                  FlexHeaderCell('Price', flex: 1),
                  FlexHeaderCell('Min', flex: 1),
                  FlexHeaderCell('CGHS', flex: 1),
                  _ActionsHeader(),
                  SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                cacheExtent: 500,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    key: ValueKey(items[index].id),
                    child: _ManagerExpandableRow(
                      item: items[index],
                      formatter: formatter,
                      onEdit: () => onEdit(items[index]),
                      onDelete: () => onDelete(items[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsHeader extends StatelessWidget {
  const _ActionsHeader();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      flex: 1,
      child: Text(
        'Actions',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ManagerExpandableRow extends StatefulWidget {
  final PriceListItem item;
  final NumberFormat formatter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ManagerExpandableRow({
    Key? key,
    required this.item,
    required this.formatter,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<_ManagerExpandableRow> createState() => _ManagerExpandableRowState();
}

class _ManagerExpandableRowState extends State<_ManagerExpandableRow>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => _isExpanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final price = item.baseCost;
    final minPrice = item.minCost;
    final cghsPrice = item.cghsPrice;
    final history = item.history;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          hoverColor: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FlexDataCell(item.deptName, flex: 2),
                FlexDataCell(item.investName,
                    flex: 3, fontWeight: FontWeight.w600),
                FlexDataCell(widget.formatter.format(price),
                    flex: 1, color: Colors.green, fontWeight: FontWeight.bold),
                FlexDataCell(widget.formatter.format(minPrice), flex: 1),
                FlexDataCell(widget.formatter.format(cghsPrice), flex: 1),
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                          onTap: widget.onEdit,
                          child: const Icon(Icons.edit,
                              size: 20, color: Colors.blue)),
                      const SizedBox(width: 12),
                      InkWell(
                          onTap: widget.onDelete,
                          child: const Icon(Icons.delete,
                              size: 20, color: Colors.red)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          _ExpandedDetails(history: history, itemId: item.investId),
        const Divider(height: 1, color: Colors.black12),
      ],
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String itemId;

  const _ExpandedDetails({required this.history, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Investigation ID', itemId),
          const SizedBox(height: 12),
          const Text('History Log',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          const Divider(),
          if (history.isEmpty)
            const Text('No history available',
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          else
            ...history.take(10).map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 80,
                          child: Text(h['action'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h['summary'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey.shade800, fontSize: 13)),
                          Text('${h['emp_name']} • ${h['time_stamp']}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      )),
                    ],
                  ),
                ))
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ',
            style: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class ManagerPriceMobileView extends StatelessWidget {
  final List<PriceListItem> items;
  final NumberFormat formatter;
  final Function(PriceListItem) onEdit;
  final Function(PriceListItem) onDelete;

  const ManagerPriceMobileView({
    super.key,
    required this.items,
    required this.formatter,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${items.length} items',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: items.length,
            cacheExtent: 400,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              return RepaintBoundary(
                key: ValueKey(items[index].id),
                child: _MobilePriceCard(
                  item: items[index],
                  formatter: formatter,
                  onEdit: () => onEdit(items[index]),
                  onDelete: () => onDelete(items[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobilePriceCard extends StatefulWidget {
  final PriceListItem item;
  final NumberFormat formatter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobilePriceCard({
    required this.item,
    required this.formatter,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MobilePriceCard> createState() => _MobilePriceCardState();
}

class _MobilePriceCardState extends State<_MobilePriceCard>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => _isExpanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(
          color: _isExpanded ? Colors.orange : AppColors.divider,
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Text(
                          item.deptName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.investName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                          Text(
                            widget.formatter.format(item.baseCost),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Min',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                          Text(
                            widget.formatter.format(item.minCost),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CGHS',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                          Text(
                            widget.formatter.format(item.cghsPrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit,
                            size: 18, color: Colors.blue),
                        label: const Text('Edit',
                            style: TextStyle(color: Colors.blue)),
                        style: TextButton.styleFrom(
                            backgroundColor:
                                Colors.blue.withValues(alpha: 0.1)),
                      ),
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        label: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _ExpandedDetails(history: item.history, itemId: item.investId),
              ],
            ),
        ],
      ),
    );
  }
}

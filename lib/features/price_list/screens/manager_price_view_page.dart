import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:anderson_crm_flutter/features/price_list/price_list.dart';
import 'add_edit_price_dialog.dart';
import 'history_sheet.dart';

import '../../../powersync/widgets/common/common_widgets.dart';

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
          ? const Center(child: CircularProgressIndicator())
          : _buildVirtualTable(state.items),
    );
  }

  Widget _buildVirtualTable(List<PriceListItem> items) {
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
                itemBuilder: (context, index) {
                  return _ManagerExpandableRow(
                    key: ValueKey(items[index].id),
                    item: items[index],
                    formatter: _currencyFormatter,
                    onEdit: () => _openEditDialog(items[index]),
                    onDelete: () => _confirmDelete(items[index]),
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

class _ManagerExpandableRowState extends State<_ManagerExpandableRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final price = item.baseCost;
    final minPrice = item.minCost;
    final cghsPrice = item.cghsPrice;
    final history = item.history;

    return RepaintBoundary(
      child: Column(
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
                      flex: 1,
                      color: Colors.green,
                      fontWeight: FontWeight.bold),
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
      ),
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

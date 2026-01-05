import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/price_list/price_list.dart';

// Shared Widgets
import '../widgets/common/common_widgets.dart';

class PriceViewPage extends ConsumerWidget {
  const PriceViewPage({Key? key}) : super(key: key);

  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(priceListProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Price List',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                height: 40,
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search (Name, Dept, >500)',
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(priceListProvider.notifier).search(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      body: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? Center(child: Text('Error: ${state.errorMessage}'))
              : state.items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No items found',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 800) {
                          return _buildDesktopVirtualTable(
                              context, state.items);
                        } else {
                          return _buildMobileList(context, state.items);
                        }
                      },
                    ),
    );
  }

  // ---------------- MOBILE VIEW (Optimized) ----------------
  Widget _buildMobileList(BuildContext context, List<PriceListItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      prototypeItem:
          const Card(child: SizedBox(height: 100, width: double.infinity)),
      itemBuilder: (context, index) {
        final item = items[index];
        final price = item.baseCost;
        final history = item.history;

        return RepaintBoundary(
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade50,
                child: Text(
                  item.investName.isNotEmpty
                      ? item.investName[0].toUpperCase()
                      : 'T',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                item.investName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                item.deptName,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              trailing: Text(
                _currencyFormatter.format(price),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Min Price', _currencyFormatter.format(item.minCost)),
                      const Divider(),
                      _buildDetailRow('CGHS Price',
                          _currencyFormatter.format(item.cghsPrice)),
                      const Divider(),
                      _buildDetailRow('Investigation ID', item.investId),
                      const SizedBox(height: 16),
                      const Text('History',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      const Divider(color: Colors.orange, thickness: 1),
                      if (history.isEmpty)
                        const Text('No history available',
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic))
                      else
                        ...history.map((h) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(h['action'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(h['time_stamp'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(h['summary'] ?? '',
                                      style: TextStyle(
                                          color: Colors.grey.shade800)),
                                  const SizedBox(height: 2),
                                  Text('${h['emp_name']} (${h['emp_mobile']})',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  const Divider(),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ---------------- DESKTOP VIEW (Optimized Virtual Table) ----------------
  Widget _buildDesktopVirtualTable(
      BuildContext context, List<PriceListItem> items) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  FlexHeaderCell('Department', flex: 2),
                  FlexHeaderCell('Investigation', flex: 3),
                  FlexHeaderCell('Price', flex: 1),
                  FlexHeaderCell('Min Price', flex: 1),
                  FlexHeaderCell('CGHS', flex: 1),
                  SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1),

            // Virtual List
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (ctx, i) =>
                    const Divider(height: 1, color: Colors.black12),
                itemBuilder: (context, index) {
                  return _DesktopExpandableRow(
                      item: items[index], formatter: _currencyFormatter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Optimized Row Widget
class _DesktopExpandableRow extends StatefulWidget {
  final PriceListItem item;
  final NumberFormat formatter;
  const _DesktopExpandableRow(
      {Key? key, required this.item, required this.formatter})
      : super(key: key);

  @override
  State<_DesktopExpandableRow> createState() => _DesktopExpandableRowState();
}

class _DesktopExpandableRowState extends State<_DesktopExpandableRow> {
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
                      flex: 3, fontWeight: FontWeight.w500),
                  FlexDataCell(widget.formatter.format(price),
                      flex: 1,
                      color: Colors.green,
                      fontWeight: FontWeight.bold),
                  FlexDataCell(widget.formatter.format(minPrice), flex: 1),
                  FlexDataCell(widget.formatter.format(cghsPrice), flex: 1),
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
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('History Log',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    const Text('No history available.',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, color: Colors.grey))
                  else
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration:
                              BoxDecoration(color: Colors.grey.shade200),
                          children: const [
                            WOTableHeader('Action'),
                            WOTableHeader('Summary'),
                            WOTableHeader('Name'),
                            WOTableHeader('Mobile'),
                            WOTableHeader('Time'),
                          ],
                        ),
                        ...history
                            .map((h) => TableRow(
                                  children: [
                                    WOTableCell(h['action'] ?? ''),
                                    WOTableCell(h['summary'] ?? ''),
                                    WOTableCell(h['emp_name'] ?? ''),
                                    WOTableCell(h['emp_mobile'] ?? ''),
                                    WOTableCell(h['time_stamp'] ?? ''),
                                  ],
                                ))
                            .toList(),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

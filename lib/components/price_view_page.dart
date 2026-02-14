import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/price_list/price_list.dart';

import '../features/core/widgets/common/common_widgets.dart';

class PriceViewPage extends ConsumerStatefulWidget {
  const PriceViewPage({Key? key}) : super(key: key);

  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  ConsumerState<PriceViewPage> createState() => _PriceViewPageState();
}

class _PriceViewPageState extends ConsumerState<PriceViewPage> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load of all items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(priceListProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          ? LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return _buildDesktopSkeleton(context);
                } else {
                  return _buildMobileSkeleton(context);
                }
              },
            )
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

  Widget _buildMobileSkeleton(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    3,
                    (index) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 10,
                          margin: const EdgeInsets.only(bottom: 4),
                          color: Colors.grey.shade100,
                        ),
                        Container(
                          width: 60,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopSkeleton(BuildContext context) {
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
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: List.generate(
                  5,
                  (index) => Expanded(
                    flex: index == 1 ? 3 : (index == 0 ? 2 : 1),
                    child: Container(
                      height: 16,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: 15,
                separatorBuilder: (ctx, i) =>
                    const Divider(height: 1, color: Colors.black12),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: List.generate(
                        5,
                        (colIndex) => Expanded(
                          flex: colIndex == 1 ? 3 : (colIndex == 0 ? 2 : 1),
                          child: Container(
                            height: 14,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildMobileList(BuildContext context, List<PriceListItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No items found',
              style: TextStyle(
                color: Colors.grey,
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
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
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
                  formatter: PriceViewPage._currencyFormatter,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

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
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (ctx, i) =>
                    const Divider(height: 1, color: Colors.black12),
                itemBuilder: (context, index) {
                  return _DesktopExpandableRow(
                      item: items[index],
                      formatter: PriceViewPage._currencyFormatter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _MobilePriceCard extends StatefulWidget {
  final PriceListItem item;
  final NumberFormat formatter;

  const _MobilePriceCard({
    required this.item,
    required this.formatter,
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isExpanded ? Colors.orange : Colors.grey.shade200,
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
                            color: Colors.black87,
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
                              color: Colors.grey,
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
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            widget.formatter.format(item.minCost),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
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
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            widget.formatter.format(item.cghsPrice),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Investigation ID', item.investId),
                  const SizedBox(height: 16),
                  const Text('History',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                  const Divider(color: Colors.orange, thickness: 1),
                  if (item.history.isEmpty)
                    const Text('No history available',
                        style: TextStyle(
                            color: Colors.grey, fontStyle: FontStyle.italic))
                  else
                    ...item.history.take(5).map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(h['summary'] ?? '',
                                  style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 13)),
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
}

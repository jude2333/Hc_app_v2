import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/widgets/common/common_widgets.dart';

final _billingSearchPod = StateProvider<String>((_) => '');
final _billingSortColumnPod = StateProvider<String>((_) => 'date');
final _billingSortAscendingPod = StateProvider<bool>((_) => false);

class BillingDesktopTable extends ConsumerWidget {
  final List<WorkOrder> orders;
  final Function(WorkOrder) onBill;
  final bool showBillAction;

  const BillingDesktopTable({
    super.key,
    required this.orders,
    required this.onBill,
    this.showBillAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_billingSearchPod);
    final sortCol = ref.watch(_billingSortColumnPod);
    final sortAsc = ref.watch(_billingSortAscendingPod);

    List<WorkOrder> filtered = search.isEmpty
        ? orders
        : orders.where((wo) {
            final term = search.toLowerCase();
            return wo.searchableText.contains(term);
          }).toList();

    filtered.sort((a, b) {
      int cmp = 0;
      switch (sortCol) {
        case 'name':
          cmp = a.patientName.compareTo(b.patientName);
          break;
        case 'total':
          cmp = a.billAmount.compareTo(b.billAmount);
          break;
        case 'date':
        default:
          cmp = a.visitDate.compareTo(b.visitDate);
          if (cmp == 0) cmp = a.visitTime.compareTo(b.visitTime);
          break;
      }
      return sortAsc ? cmp : -cmp;
    });

    void handleSort(String sortKey) {
      if (sortCol == sortKey) {
        ref.read(_billingSortAscendingPod.notifier).state = !sortAsc;
      } else {
        ref.read(_billingSortColumnPod.notifier).state = sortKey;
        ref.read(_billingSortAscendingPod.notifier).state = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _DebouncedSearchBar(
            hintText: 'Search by name, mobile, bill number...',
            onSearch: (v) => ref.read(_billingSearchPod.notifier).state = v,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 2,
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const HeaderCell('No', flex: 1),
                        SortableHeader(
                          label: 'Patient Name',
                          sortKey: 'name',
                          flex: 3,
                          currentSortColumn: sortCol,
                          isAscending: sortAsc,
                          onSort: handleSort,
                        ),
                        const HeaderCell('Mobile', flex: 2),
                        SortableHeader(
                          label: 'Date',
                          sortKey: 'date',
                          flex: 2,
                          currentSortColumn: sortCol,
                          isAscending: sortAsc,
                          onSort: handleSort,
                        ),
                        const HeaderCell('Time', flex: 1),
                        SortableHeader(
                          label: 'Total',
                          sortKey: 'total',
                          flex: 2,
                          currentSortColumn: sortCol,
                          isAscending: sortAsc,
                          onSort: handleSort,
                        ),
                        const HeaderCell('Tech Status', flex: 2),
                        const HeaderCell('Server Status', flex: 2),
                        if (showBillAction)
                          const HeaderCell('Actions', flex: 2),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Colors.black12),
                      itemBuilder: (context, index) {
                        final order = filtered[index];

                        return RepaintBoundary(
                          key: ValueKey(order.id),
                          child: _BillingExpandableRow(
                            key: ValueKey('row_${order.id}'),
                            index: index + 1,
                            order: order,
                            onBill: onBill,
                            showBillAction: showBillAction,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebouncedSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;

  const _DebouncedSearchBar({
    required this.hintText,
    required this.onSearch,
  });

  @override
  State<_DebouncedSearchBar> createState() => _DebouncedSearchBarState();
}

class _DebouncedSearchBarState extends State<_DebouncedSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _controller.clear();
                  widget.onSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _BillingExpandableRow extends StatefulWidget {
  final int index;
  final WorkOrder order;
  final Function(WorkOrder) onBill;
  final bool showBillAction;

  const _BillingExpandableRow({
    super.key,
    required this.index,
    required this.order,
    required this.onBill,
    required this.showBillAction,
  });

  @override
  State<_BillingExpandableRow> createState() => _BillingExpandableRowState();
}

class _BillingExpandableRowState extends State<_BillingExpandableRow>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => _isExpanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final order = widget.order;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FlexDataCell('${widget.index}', flex: 1),
                _NameCell(order: order, flex: 3),
                FlexDataCell(order.mobile, flex: 2),
                FlexDataCell(order.formattedShortDate, flex: 2),
                FlexDataCell(order.visitTime, flex: 1),
                FlexDataCell(order.formattedBillAmount, flex: 2),
                Expanded(flex: 2, child: StatusChip(status: order.status)),
                Expanded(
                    flex: 2, child: ServerChip(status: order.serverStatus)),
                if (widget.showBillAction)
                  Expanded(
                    flex: 2,
                    child: _canBill(order)
                        ? IconButton(
                            icon: const Icon(Icons.receipt_long,
                                color: Colors.blue, size: 20),
                            tooltip: 'Bill Order',
                            onPressed: () => widget.onBill(order),
                          )
                        : const SizedBox(),
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
        if (_isExpanded) _ExpandedContent(order: order),
      ],
    );
  }

  bool _canBill(WorkOrder order) {
    return order.status == 'Finished' && order.serverStatus == 'Received';
  }
}

class _ExpandedContent extends StatelessWidget {
  final WorkOrder order;

  const _ExpandedContent({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Address', order.address),
          _DetailRow('Pincode', order.pincode),
          _DetailRow('Ref By', order.doctorName),
          if (order.billNumber.isNotEmpty)
            _DetailRow('Bill Number', order.billNumber),
          if (order.labNumber.isNotEmpty)
            _DetailRow('Lab Number', order.labNumber),
          const SizedBox(height: 12),
          if (order.testItems.isNotEmpty) ...[
            const Text('Test Items',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _TestItemsTable(testItems: order.testItems),
            const SizedBox(height: 8),
            Text('Total: ${order.formattedBillAmount}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  final WorkOrder order;
  final int flex;

  const _NameCell({required this.order, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Expanded(
            child: Text(
              order.patientName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (order.vip)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Chip(
                label: Text('VIP', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.amber,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (order.urgent)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Chip(
                label: Text('URGENT', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value.isEmpty ? 'N/A' : value)),
        ],
      ),
    );
  }
}

class _TestItemsTable extends StatelessWidget {
  final List<dynamic> testItems;

  const _TestItemsTable({required this.testItems});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(1),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Colors.white),
          children: [
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Dept ID',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Dept Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Invest ID',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Investigation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('Cost',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        ...testItems.map((item) {
          final map = item as Map<String, dynamic>;
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(map['dept_id']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(map['dept_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(map['invest_id']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(map['invest_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('₹${map['base_cost']?.toString() ?? '0'}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          );
        }),
      ],
    );
  }
}

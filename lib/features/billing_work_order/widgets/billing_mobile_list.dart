import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';

final _mobileSearchPod = StateProvider<String>((_) => '');

class BillingMobileList extends ConsumerWidget {
  final List<WorkOrder> orders;
  final Function(WorkOrder) onBill;
  final bool showBillAction;

  const BillingMobileList({
    super.key,
    required this.orders,
    required this.onBill,
    this.showBillAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_mobileSearchPod);

    final filtered = search.isEmpty
        ? orders
        : orders.where((wo) {
            final term = search.toLowerCase();
            return wo.searchableText.contains(term);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _DebouncedSearchBar(
            hintText: 'Search by name, mobile...',
            onSearch: (v) => ref.read(_mobileSearchPod.notifier).state = v,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = filtered[index];
              return RepaintBoundary(
                key: ValueKey(order.id),
                child: _BillingCard(
                  key: ValueKey('card_${order.id}'),
                  order: order,
                  onBill: onBill,
                  showBillAction: showBillAction && _canBill(order),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _canBill(WorkOrder order) {
    return order.status == 'Finished' && order.serverStatus == 'Received';
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
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

class _BillingCard extends StatelessWidget {
  final WorkOrder order;
  final Function(WorkOrder) onBill;
  final bool showBillAction;

  const _BillingCard({
    super.key,
    required this.order,
    required this.onBill,
    required this.showBillAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (order.vip)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('VIP',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      if (order.urgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('URGENT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.mobile} • ${order.formattedShortDate} ${order.visitTime}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              _StatusChip(order.status),
              const SizedBox(width: 8),
              _ServerStatusChip(order.serverStatus),
              const Spacer(),
              Text(
                order.formattedBillAmount,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        children: [
          _DetailRow('Address', order.address),
          _DetailRow('Pincode', order.pincode),
          _DetailRow('Ref By', order.doctorName),
          if (order.billNumber.isNotEmpty)
            _DetailRow('Bill Number', order.billNumber),
          if (order.labNumber.isNotEmpty)
            _DetailRow('Lab Number', order.labNumber),
          if (order.testItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Test Items',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...order.testItems.map((item) {
              final map = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        map['invest_name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '₹${map['base_cost']?.toString() ?? '0'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Total: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  order.formattedBillAmount,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          if (showBillAction) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onBill(order),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Bill Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
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
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
              child: Text(value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'finished':
        color = Colors.green;
        break;
      case 'assigned':
        color = Colors.blue;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ServerStatusChip extends StatelessWidget {
  final String status;

  const _ServerStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label = status;

    switch (status.toLowerCase()) {
      case 'billed':
        color = Colors.green;
        break;
      case 'received':
        color = Colors.blue;
        label = 'Unbilled';
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

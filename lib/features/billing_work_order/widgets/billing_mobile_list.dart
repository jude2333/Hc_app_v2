import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/theme/app_colors.dart';
import 'package:anderson_crm_flutter/features/theme/app_spacing.dart';

import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/work_order_chips.dart';
import '../providers/billing_work_order_provider.dart';

class BillingMobileList extends ConsumerWidget {
  final List<WorkOrder> orders;
  final Function(WorkOrder) onBill;
  final Function(WorkOrder)? onSend;
  final bool showBillAction;

  const BillingMobileList({
    super.key,
    required this.orders,
    required this.onBill,
    this.onSend,
    this.showBillAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(billingSearchPod);
    final storage = ref.watch(storageRepositoryProvider);

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
            onSearch: (v) => ref.read(billingSearchPod.notifier).state = v,
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
                  storage: storage,
                  onBill: onBill,
                  onSend: onSend,
                  showBillAction: showBillAction && _canBill(order),
                  showSendAction: _canSend(order),
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

  bool _canSend(WorkOrder order) {
    return order.status == 'Finished' &&
        order.serverStatus == 'Received' &&
        order.sentStatus != 'sent';
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
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

class _BillingCard extends StatelessWidget {
  final WorkOrder order;
  final StorageRepository storage;
  final Function(WorkOrder) onBill;
  final Function(WorkOrder)? onSend;
  final bool showBillAction;
  final bool showSendAction;

  const _BillingCard({
    super.key,
    required this.order,
    required this.storage,
    required this.onBill,
    this.onSend,
    required this.showBillAction,
    required this.showSendAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
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
                      _buildBadges(),
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
              if (order.sentStatus == 'sent') ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'sent',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                order.formattedCalculatedTotal,
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
          _DetailRow('Assigned To', order.assignedTo),
          if (order.prescriptionPhoto.isNotEmpty)
            _FileRow(
              label: 'Prescription',
              filePath: order.prescriptionPhoto,
              storage: storage,
            ),
          if (order.prescriptionPath.isNotEmpty)
            _FileRow(
              label: 'Prescription Photo',
              filePath: order.prescriptionPath,
              storage: storage,
            ),
          if (order.proformaPath.isNotEmpty)
            _FileRow(
              label: 'Proforma Invoice',
              filePath: order.proformaPath,
              storage: storage,
            ),
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
                      flex: 3,
                      child: Text(
                        map['invest_name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '₹${map['base_cost']?.toString() ?? '0'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '₹${map['min_cost']?.toString() ?? '0'}',
                        style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            color: Colors.grey.shade600),
                        textAlign: TextAlign.right,
                      ),
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
                  order.formattedCalculatedTotal,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (showBillAction)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onBill(order),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Bill'),
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
              if (showBillAction && showSendAction) const SizedBox(width: 12),
              if (showSendAction)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onSend?.call(order),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadges() {
    final flags = <String>[];
    if (order.urgent) flags.add('Urgent');
    if (order.vip) flags.add('VIP');
    if (order.credit > 0) {
      flags.add(order.credit == 1 ? 'Credit' : 'Trial');
    }
    if ((order.b2bClientId ?? 0) > 0) flags.add('B2B');

    if (flags.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        flags.join(' '),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
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
            width: 120,
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

class _FileRow extends StatelessWidget {
  final String label;
  final String filePath;
  final StorageRepository storage;

  const _FileRow({
    required this.label,
    required this.filePath,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = FileService.getFileName(filePath);
    final fileCount = filePath.contains(',')
        ? '${filePath.split(',').length} files'
        : fileName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            child: ActionLinkChip(
              label: fileCount,
              color: Colors.blue,
              onTap: () => _openFile(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openFile(BuildContext context) {
    if (filePath.isEmpty) return;

    final files = filePath.contains(',')
        ? filePath.split(',').map((f) => f.trim()).toList()
        : [filePath];

    if (files.length == 1) {
      FileViewer.view(context, s3Path: files.first);
    } else {
      FilePickerDialog.show(
        context,
        files: files,
        title: 'View / Download Files',
        onAction: (path, action) {
          if (action == 'view') {
            FileViewer.view(context, s3Path: path);
          } else {
            final fileService = FileService(
              dio: Dio(),
              storage: storage,
            );
            fileService.downloadAndOpen(context, path);
          }
        },
      );
    }
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
        borderRadius: AppRadius.mdAll,
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
        borderRadius: AppRadius.mdAll,
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

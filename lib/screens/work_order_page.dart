// import 'package:anderson_crm_flutter/database/work_orderDb.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/services/workOrder_service.dart';
import 'package:anderson_crm_flutter/screens/add_work_order_page.dart';
import 'time_line_page.dart';
import 'assign_technicians.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';

import 'canceled_work_order_page.dart';
import 'tech_engagement_page.dart';

/* ---------------  providers --------------- */
final selectedDatePod = StateProvider<DateTime>((_) => DateTime.now());

final workOrdersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, dateStr) async* {
    final service = ref.read(workOrderDBServiceProvider);

    // 1. initial load (same server call you already use)
    yield await service.listRemoteData(dateStr);

    // 2. re-fetch **only** when we know something changed
    final dbHandler = ref.watch(dbHandlerProvider);
    await for (final _ in dbHandler.workOrderRefreshStream) {
      yield await service.listRemoteData(dateStr);
    }
  },
);
final _searchPod = StateProvider<String>((_) => '');
final _expandedRowPod = StateProvider<String?>((_) => null);

/* ---------------  main page --------------- */
class WorkOrderPage extends ConsumerWidget {
  const WorkOrderPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDatePod);
    final dateStr = DateFormat('yyyy-MM-dd').format(selected);
    final asyncList = ref.watch(workOrdersProvider(dateStr));
    final now = DateTime.now();
    final dateOffsets = [3, 2, 1, 0, -1, -2, -3, -4, -5];
    final dateChips = dateOffsets.map((off) {
      final date = now.add(Duration(days: off));
      String label;
      if (off == 3 || off == 2 || off <= -2) {
        label = DateFormat('yyyy-MM-dd').format(date);
      } else if (off == 1) {
        label = 'NEXTDAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == 0) {
        label = 'TODAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == -1) {
        label = 'YESTERDAY\n${DateFormat('MM-dd').format(date)}';
      } else {
        label = DateFormat('yyyy-MM-dd').format(date);
      }
      return _DateChipProps(date, label);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Orders'),
        actions: [
          IconButton(
            tooltip: 'Cancelled Work Orders',
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CanceledWorkOrderPage(),
                ),
              );
            },
          ),
          IconButton(
              tooltip: 'Price view',
              icon: const Icon(Icons.list_alt_outlined),
              onPressed: () {
                // TODO: Implement price view
              }),
          IconButton(
            tooltip: 'Tech engagement',
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TechEngagementPage(),
                ),
              );
            },
          ),
          IconButton(
              tooltip: 'Add Work Order',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showAddWorkOrderDialog(context, ref)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dateChips.length,
              itemBuilder: (_, idx) {
                final chip = dateChips[idx];
                final isSel = chip.date.year == selected.year &&
                    chip.date.month == selected.month &&
                    chip.date.day == selected.day;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(chip.label, textAlign: TextAlign.center),
                    backgroundColor: isSel
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    onPressed: () =>
                        ref.read(selectedDatePod.notifier).state = chip.date,
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (rows) => DesktopTable(rows: rows),
      ),
    );
  }
}

// Future<void> _showAddWorkOrderDialog(
//     BuildContext context, WidgetRef ref) async {
//   final result = await showDialog<String>(
//     context: context,
//     builder: (context) => const AddWorkOrderPage(),
//   );

//   if (result == 'refresh') {
//     // Refresh the work order list
//     ref.invalidate(workOrdersProvider);
//   }
// }

void _showAddWorkOrderDialog(BuildContext context, WidgetRef ref) {
  Navigator.of(context)
      .push(
    MaterialPageRoute(
      builder: (context) => const AddWorkOrderPage(),
      fullscreenDialog: true, // This is important for mobile
    ),
  )
      .then((value) {
    if (value == 'refresh') {
      // Refresh your work orders list
      ref.invalidate(workOrdersProvider);
    }
  });
}

/* ---------------  data table --------------- */
class DesktopTable extends ConsumerWidget {
  final List<Map<String, dynamic>> rows;
  const DesktopTable({required this.rows});

  // Define total table width as sum of all column widths
  static const double totalTableWidth =
      50 + 180 + 80 + 60 + 120 + 110 + 80 + 120 + 130 + 150 + 120 + 50; // 1250

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchPod);
    final expandedRowId = ref.watch(_expandedRowPod);
    final filtered =
        search.isEmpty ? rows : Util.search(rows, search.toLowerCase());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(_searchPod.notifier).state = v,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade400, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('No', width: 50),
                        _buildHeaderCell('Name', width: 180),
                        _buildHeaderCell('Gender', width: 80),
                        _buildHeaderCell('Age', width: 60),
                        _buildHeaderCell('Mobile', width: 120),
                        _buildHeaderCell('Date', width: 110),
                        _buildHeaderCell('Time', width: 80),
                        _buildHeaderCell('Tech. Status', width: 120),
                        _buildHeaderCell('Server Status', width: 130),
                        _buildHeaderCell('Assigned To', width: 150),
                        _buildHeaderCell('Actions', width: 120),
                        _buildHeaderCell('', width: 50),
                      ],
                    ),
                  ),
                  // Data rows
                  ..._buildRowsWithExpansion(
                      context, ref, filtered, expandedRowId),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRowsWithExpansion(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> filtered, String? expandedRowId) {
    List<Widget> allRows = [];

    for (int i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      final itemId = item['_id']?.toString() ?? i.toString();
      final isExpanded = expandedRowId == itemId;

      // Main row
      allRows.add(
        InkWell(
          onTap: () => _toggleExpand(ref, itemId),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                _buildCell('${i + 1}', width: 50),
                _buildCell('', width: 180, child: _NameCell(item: item)),
                _buildCell('${item['gender'] ?? ''}', width: 80),
                _buildCell('${item['age'] ?? ''}', width: 60),
                _buildCell('${item['mobile'] ?? ''}', width: 120),
                _buildCell('${item['appointment_date'] ?? ''}', width: 110),
                _buildCell('${item['appointment_time'] ?? ''}', width: 80),
                // _buildCell('',
                // width: 120,
                // child: _StatusChip(
                //   status: '${item['status'] ?? ''}',
                //   // onTap: () => _showAssignDialog(context, ref, item),
                // )),
                _buildCell('', width: 130, child: _ServerChip(item: item)),
                _buildCell('${item['assigned_to'] ?? ''}', width: 150),
                _buildCell('', width: 120, child: _Actions(item: item)),
                _buildCell('',
                    width: 50,
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    )),
              ],
            ),
          ),
        ),
      );

      // Expanded row - now with fixed width matching table
      if (isExpanded) {
        allRows.add(
          SizedBox(
            width: totalTableWidth,
            child: _ExpandedRowContent(
              item: item,
              tableWidth: totalTableWidth,
            ),
          ),
        );
      }
    }

    return allRows;
  }

  Widget _buildCell(String text, {required double width, Widget? child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      child: child ?? Text(text, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _toggleExpand(WidgetRef ref, String itemId) {
    final current = ref.read(_expandedRowPod);
    ref.read(_expandedRowPod.notifier).state =
        current == itemId ? null : itemId;
  }
}

/* ---------------  expanded row content --------------- */
class _ExpandedRowContent extends StatelessWidget {
  final Map<String, dynamic> item;
  final double tableWidth;
  const _ExpandedRowContent({
    required this.item,
    required this.tableWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tableWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Section - now full width
          SizedBox(
            width: tableWidth - 32, // Subtract padding
            child: _buildInfoTable(context),
          ),
          const SizedBox(height: 12),

          // Prescription Photo
          if (item['pres_photo'] != null) ...[
            _buildPrescriptionSection(context),
            const SizedBox(height: 12),
          ],

          // Cancellation Reason
          if (_getCancelStatus(item)) ...[
            _buildCancellationSection(context),
            const SizedBox(height: 12),
          ],

          // Process Steps
          if (item['process'] != null) ...[
            _buildProcessSteps(context),
            const SizedBox(height: 12),
          ],

          // Remarks
          if (item['remarks'] != null) ...[
            _buildRemarksSection(context),
            const SizedBox(height: 12),
          ],

          // Bill Info
          if (item['server_status'] == 'Billed') ...[
            _buildBillInfo(context),
            const SizedBox(height: 12),
          ],

          // Report Status
          if (_getReportStatus(item)) ...[
            _buildReportSection(context),
            const SizedBox(height: 12),
          ],

          // Timeline Button
          // _buildTimelineButton(context),
        ],
      ),
    );
  }

  Widget _buildInfoTable(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2), // Address
        1: FlexColumnWidth(1), // Pincode
        2: FlexColumnWidth(3), // Additional Info (larger)
        3: FlexColumnWidth(2), // Ref. By.
        4: FlexColumnWidth(2), // Email
      },
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _TableHeader('Address'),
            _TableHeader('Pincode'),
            _TableHeader('Additional Info'),
            _TableHeader('Ref. By.'),
            _TableHeader('Email'),
          ],
        ),
        TableRow(
          children: [
            _TableCell('${item['address'] ?? ''}'),
            _TableCell('${item['pincode'] ?? ''}'),
            _TableCell('${item['free_text'] ?? ''}'),
            _TableCell(_getRefBy()),
            _TableCell('${item['email'] ?? ''}'),
          ],
        ),
      ],
    );
  }

  String _getRefBy() {
    if (item['b2b_client_id'] != null) {
      return 'B2B: ${item['b2b_client_name'] ?? ''}';
    }
    return 'Dr. ${item['doctor_name'] ?? ''}';
  }

  Widget _buildPrescriptionSection(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Prescription:'),
          backgroundColor: Colors.red.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.red),
        ),
        ActionChip(
          label: Text(_getName(item['pres_photo'])),
          backgroundColor: Colors.blue.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.blue),
          onPressed: () {
            // TODO: Implement prescription download
            debugPrint('Download prescription: ${item['pres_photo']}');
          },
        ),
      ],
    );
  }

  Widget _buildCancellationSection(BuildContext context) {
    return Chip(
      label: Text('Cancellation Reason: ${_getReason()}'),
      backgroundColor: Colors.red.withOpacity(0.15),
      labelStyle: const TextStyle(color: Colors.red),
    );
  }

  Widget _buildProcessSteps(BuildContext context) {
    final process = item['process'] as Map<String, dynamic>?;
    if (process == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (process['first_step'] != null) ...[
          _buildProcessStep(
              'Step-1', 'Reason For Delay: ${process['first_step']}'),
          const SizedBox(height: 8),
        ],
        if (process['second_step'] != null) ...[
          _buildProformaStep(process['second_step']),
          const SizedBox(height: 8),
        ],
        if (process['third_step'] != null) ...[
          _buildProcessStep('Step-3', 'Bill Amount: ${process['third_step']}'),
          const SizedBox(height: 8),
        ],
        if (process['fourth_step'] != null) ...[
          _buildProcessStep('Step-4', 'OTP: ${process['fourth_step']}'),
          const SizedBox(height: 8),
        ],
        if (process['fifth_step'] != null) ...[
          _buildPrescriptionPhotoStep(process['fifth_step']),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildProcessStep(String label, String content) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(label),
          backgroundColor: Colors.orange.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.orange),
        ),
        Text(content),
      ],
    );
  }

  Widget _buildProformaStep(dynamic stepData) {
    String statusText = 'Sent';
    if (item['b2b_client_id'] != null) {
      statusText = 'Not Sent For B2B Client';
    } else if (item['credit'] == 1) {
      statusText = 'Not Sent For Credit Client';
    } else if (item['credit'] == 2) {
      statusText = 'Not Sent For Trial Client';
    }

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Step-2'),
          backgroundColor: Colors.orange.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.orange),
        ),
        const Text('Proforma Invoice:'),
        Chip(
          label: Text(statusText),
          backgroundColor: (statusText == 'Sent' ? Colors.green : Colors.red)
              .withOpacity(0.15),
          labelStyle: TextStyle(
              color: statusText == 'Sent' ? Colors.green : Colors.red),
        ),
        ActionChip(
          label: const Text('Proforma Invoice'),
          backgroundColor: Colors.blue.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.blue),
          onPressed: () {
            // TODO: Implement download
            debugPrint('Download proforma: $stepData');
          },
        ),
      ],
    );
  }

  Widget _buildPrescriptionPhotoStep(dynamic stepData) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Step-5'),
          backgroundColor: Colors.orange.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.orange),
        ),
        const Text('Prescription Photo:'),
        ActionChip(
          label: Text(_getPrescrptionFileNames('$stepData')),
          backgroundColor: Colors.blue.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.blue),
          onPressed: () {
            // TODO: Implement download
            debugPrint('Download prescription photos: $stepData');
          },
        ),
      ],
    );
  }

  Widget _buildRemarksSection(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Remarks'),
          backgroundColor: Colors.orange.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.orange),
        ),
        Text('${item['remarks']}'),
      ],
    );
  }

  Widget _buildBillInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              label: const Text('Bill No:'),
              backgroundColor: Colors.orange.withOpacity(0.15),
              labelStyle: const TextStyle(color: Colors.orange),
            ),
            Chip(
              label: Text('${item['bill_number'] ?? ''}'),
              backgroundColor: Colors.blue.withOpacity(0.15),
              labelStyle: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              label: const Text('Lab No:'),
              backgroundColor: Colors.orange.withOpacity(0.15),
              labelStyle: const TextStyle(color: Colors.orange),
            ),
            Chip(
              label: Text('${item['lab_number'] ?? ''}'),
              backgroundColor: Colors.blue.withOpacity(0.15),
              labelStyle: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportSection(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Lab Result:'),
          backgroundColor: Colors.orange.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.orange),
        ),
        Chip(
          label: Text(
              '${item['status_in_number'] ?? ''} ${item['report_status'] ?? ''}'),
          backgroundColor: _getReportColor().withOpacity(0.15),
          labelStyle: TextStyle(color: _getReportColor()),
        ),
        ActionChip(
          label: const Text('Report PDF'),
          backgroundColor: Colors.blue.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.blue),
          avatar: const Icon(Icons.thumb_up, size: 16),
          onPressed: () {
            // TODO: Implement PDF download
            debugPrint('Download report: ${item['report_path']}');
          },
        ),
      ],
    );
  }

  // Widget _buildTimelineButton(BuildContext context) {
  //   return ActionChip(
  //     label: const Text('Time Line'),
  //     backgroundColor: Colors.blue.withOpacity(0.15),
  //     labelStyle: const TextStyle(color: Colors.blue),
  //     onPressed: () {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => TimeLinePage(item: item),
  //         ),
  //       );
  //     },
  //   );
  // }

  bool _getCancelStatus(Map<String, dynamic> item) {
    return item['status'] == 'cancelled';
  }

  String _getReason() {
    return item['cancel_reason'] ?? 'Reason Not Given.';
  }

  bool _getReportStatus(Map<String, dynamic> item) {
    return item['server_status'] == 'Billed' && item['report_path'] != null;
  }

  Color _getReportColor() {
    final status = '${item['report_status']}'.toLowerCase();
    if (status == 'complete') return Colors.green;
    if (status == 'error') return Colors.red;
    return Colors.orange;
  }

  String _getName(dynamic name) {
    if (name == null) return '';
    String nameStr = name.toString();
    if (nameStr.contains('/')) {
      return nameStr.substring(nameStr.lastIndexOf('/') + 1);
    }
    return nameStr;
  }

  String _getPrescrptionFileNames(String name) {
    List<String> aName = [];
    if (name.contains(',')) {
      aName = name.split(',');
    } else {
      aName.add(name);
    }
    if (aName.length > 1) {
      return '${aName.length} files.';
    }
    return _getName(name);
  }
}

/* ---------------  helper widgets for expanded content --------------- */
class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text),
    );
  }
}

/* ---------------  existing helper widgets --------------- */
class _NameCell extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NameCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final flags = <String>[];
    if (item['urgent'] == true) flags.add('Urgent');
    if (item['vip_client'] == true) flags.add('VIP');
    if (item['credit'] == 1) flags.add('Credit');
    if (item['credit'] == 2) flags.add('Trial');
    if (item['b2b_client_id'] != null) flags.add('B2B');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${item['name'] ?? ''}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              flags.join(' '),
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _StatusChip({required this.status, required this.onTap});

  Color _color() {
    final s = status.toLowerCase();
    if (s.startsWith('un')) return Colors.red;
    if (s == 'assigned') return Colors.blue;
    if (s == 'cancelled') return Colors.grey;
    if (s == 'finished') return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final isClickable = s == 'unassigned' || s == 'assigned';

    return InkWell(
      onTap: isClickable ? onTap : null,
      child: Chip(
        label: Text(status),
        backgroundColor: _color().withOpacity(.15),
        labelStyle: TextStyle(color: _color()),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServerChip({required this.item});

  Color _color() {
    final s = '${item['server_status']}'.toLowerCase();
    if (s == 'billed') return Colors.green;
    if (s == 'unbilled') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final status = item['server_status'] == 'Received'
        ? 'Unbilled'
        : '${item['server_status']}';
    return Chip(
      label: Text(status),
      backgroundColor: _color().withOpacity(.15),
      labelStyle: TextStyle(color: _color()),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Actions extends StatelessWidget {
  final Map<String, dynamic> item;
  const _Actions({required this.item});

  @override
  Widget build(BuildContext context) {
    final finished = ['Finished', 'cancelled'].contains(item['status']);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.content_copy, size: 18),
          onPressed: () {
            // TODO: Implement copy
            debugPrint('Copy item: ${item['_id']}');
          },
        ),
        if (!finished) ...[
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () {
              // TODO: Implement edit
              debugPrint('Edit item: ${item['_id']}');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () {
              // TODO: Implement delete
              debugPrint('Delete item: ${item['_id']}');
            },
          ),
        ],
      ],
    );
  }
}

/* ---------------  models --------------- */
class _DateChipProps {
  final DateTime date;
  final String label;
  _DateChipProps(this.date, this.label);
}

/* ---------------  stubs --------------- */
// void _showAssignDialog(
//     BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
//   showAssignTechnicianDialog(
//     context,
//     ref,
//     item,
//     (techId, techName) async {
//       await _assignTechnician(context, ref, item, techId, techName);
//     },
//   );
// }

Future<void> _assignTechnician(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> workOrder,
  String techId,
  String techName,
) async {
  try {
    final workOrderService = ref.read(workOrderDBServiceProvider);
    final storage = ref.read(storageServiceProvider);

    // Get current timestamp
    final timeStamp = DateTime.now().toString();
    final workOrderCreatedBy = storage.getFromSession("logged_in_emp_name");
    final assignmentLog =
        "$timeStamp-$workOrderCreatedBy- Work Order Assigned To $techName";

    // Store previous assignment if exists
    if (workOrder['assigned_to'] != null) {
      workOrder['prev_assigned_to'] = workOrder['assigned_to'];
      workOrder['prev_assigned_id'] = workOrder['assigned_id'];
    }

    // Update work order
    workOrder['status'] = 'assigned';
    workOrder['assigned_to'] = techName;
    workOrder['assigned_id'] = techId;

    // Add to timeline
    if (workOrder['time_line'] == null) {
      workOrder['time_line'] = [];
    }
    (workOrder['time_line'] as List).add(assignmentLog);

    // Update in database
    final result = await workOrderService.doUpdate2(workOrder);

    if (result == 'OK') {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assigned Successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Show notification dialog
      _showNotificationDialog(context, ref, workOrder, techName);

      // Refresh the work order list
      ref.invalidate(workOrdersProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error Occurred: $result'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    debugPrint('Error assigning technician: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _showNotificationDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> workOrder,
  String techName,
) {
  bool sendSms = true;
  bool sendWhatsApp = true;
  bool sendEmail =
      workOrder['email'] != null && workOrder['email'].toString().isNotEmpty;

  // Save the parent context (the one with Scaffold)
  final scaffoldContext = context;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange,
            child: const Text(
              'Assigned Successfully',
              style: TextStyle(color: Colors.white),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you wish to inform ${workOrder['name']} (Mob: ${workOrder['mobile']}) about the technician?',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('SMS'),
                value: sendSms,
                onChanged: (value) => setState(() => sendSms = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('WhatsApp'),
                value: sendWhatsApp,
                onChanged: (value) =>
                    setState(() => sendWhatsApp = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Email'),
                value: sendEmail,
                onChanged: (value) =>
                    setState(() => sendEmail = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog first

                // Use the saved scaffold context
                await _sendNotifications(
                  scaffoldContext, // ✅ Use parent context
                  ref,
                  workOrder,
                  techName,
                  sendSms,
                  sendWhatsApp,
                  sendEmail,
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ),
  );
}

// Add this function to send notifications
Future<void> _sendNotifications(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> workOrder,
  String techName,
  bool sendSms,
  bool sendWhatsApp,
  bool sendEmail,
) async {
  // Your SMS, WhatsApp, Email sending logic
  if (sendSms) {
    debugPrint('Sending SMS to ${workOrder['mobile']}');
    // TODO: Actual SMS sending
  }

  if (sendWhatsApp) {
    debugPrint('Sending WhatsApp to ${workOrder['mobile']}');
    // TODO: Actual WhatsApp sending
  }

  if (sendEmail) {
    debugPrint('Sending Email to ${workOrder['email']}');
    // TODO: Actual Email sending
  }

  // Now show the SnackBar with the valid context
  if (context.mounted) {
    // ✅ Check if context is still valid
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications sent successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

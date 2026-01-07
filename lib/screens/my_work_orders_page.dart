import 'package:anderson_crm_flutter/database/work_orderDb.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/services/workOrder_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'hc_process_page.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import '../services/dbHandler_service.dart';

final myWorkOrdersProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  yield await _fetchServerList(ref);

  final dbHandler = ref.watch(dbHandlerProvider);
  await for (final _ in dbHandler.workOrderRefreshStream) {
    yield await _fetchServerList(ref);
  }
});

Future<List<Map<String, dynamic>>> _fetchServerList(Ref ref) =>
    ref.read(workOrderDBServiceProvider).assignedListRemote(
        ref.read(storageServiceProvider).getFromSession('logged_in_emp_id') ??
            '');

final _searchPod = StateProvider<String>((_) => '');
final _expandedRowPod = StateProvider<String?>((_) => null);

class MyWorkOrdersPage extends ConsumerWidget {
  const MyWorkOrdersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(myWorkOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'My Work Orders',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Price view',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () {
              debugPrint('Price view clicked');
            },
          ),
          IconButton(
            tooltip: 'Tech engagement',
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () {
              debugPrint('Tech engagement clicked');
            },
          ),
        ],
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
        data: (rows) => _DesktopTable(rows: rows),
      ),
    );
  }
}

class _DesktopTable extends ConsumerWidget {
  final List<Map<String, dynamic>> rows;
  const _DesktopTable({required this.rows});

  static const double totalTableWidth =
      50 + 180 + 80 + 60 + 120 + 110 + 80 + 120 + 130 + 150 + 120 + 50;

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
                        _buildHeaderCell('Ref. By', width: 120),
                        _buildHeaderCell('Status', width: 130),
                        _buildHeaderCell('Server Status', width: 150),
                        _buildHeaderCell('Actions', width: 120),
                        _buildHeaderCell('', width: 50),
                      ],
                    ),
                  ),
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

  List<Widget> _buildRowsWithExpansion(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> filtered,
    String? expandedRowId,
  ) {
    List<Widget> allRows = [];

    for (int i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      final itemId = item['_id']?.toString() ?? i.toString();
      final isExpanded = expandedRowId == itemId;

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
                _buildCell('${item['doctor_name'] ?? ''}', width: 120),
                _buildCell('', width: 130, child: _StatusChip(item: item)),
                _buildCell('', width: 150, child: _ServerChip(item: item)),
                _buildCell('', width: 120, child: _Actions(item: item)),
                _buildCell(
                  '',
                  width: 50,
                  child: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

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
          SizedBox(
            width: tableWidth - 32,
            child: _buildInfoTable(context),
          ),
          const SizedBox(height: 12),
          if (item['pres_photo'] != null &&
              item['pres_photo'].toString().isNotEmpty) ...[
            _buildPrescriptionSection(context),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTable(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(3),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(2),
      },
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _TableHeader('Address'),
            _TableHeader('Pincode'),
            _TableHeader('Additional Info'),
            _TableHeader('Status'),
            _TableHeader('Assigned To'),
          ],
        ),
        TableRow(
          children: [
            _TableCell('${item['address'] ?? ''}'),
            _TableCell('${item['pincode'] ?? ''}'),
            _TableCell('${item['free_text'] ?? ''}'),
            _TableCell('${item['status'] ?? ''}'),
            _TableCell('${item['assigned_to'] ?? ''}'),
          ],
        ),
      ],
    );
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
          label: Text(Util.getName(item['pres_photo'].toString())),
          backgroundColor: Colors.blue.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.blue),
          onPressed: () {
            debugPrint('View/Download prescription: ${item['pres_photo']}');
          },
        ),
      ],
    );
  }
}

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
    if (item['b2b_client_id'] != null && item['b2b_client_id'] != 0)
      flags.add('B2B');

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
  final Map<String, dynamic> item;
  const _StatusChip({required this.item});

  Color _color(String status) {
    final s = status.toLowerCase();
    if (s.startsWith('un')) return Colors.red;
    if (s == 'assigned') return Colors.blue;
    if (s == 'cancelled') return Colors.grey;
    if (s == 'finished') return Colors.green;
    if (s == 'na') return Colors.grey;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final status = '${item['status'] ?? ''}';
    return Chip(
      label: Text(status),
      backgroundColor: _color(status).withOpacity(.15),
      labelStyle: TextStyle(color: _color(status)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ServerChip extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServerChip({required this.item});

  Color _color(String status) {
    final s = status.toLowerCase();
    if (s == 'billed') return Colors.green;
    if (s == 'unbilled' || s == 'received') return Colors.red;
    if (s == 'waiting') return Colors.grey;
    if (s == 'cancelled') return Colors.grey;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    String status = item['server_status'] == 'Received'
        ? 'Unbilled'
        : '${item['server_status'] ?? ''}';

    return Chip(
      label: Text(status),
      backgroundColor: _color(status).withOpacity(.15),
      labelStyle: TextStyle(color: _color(status)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Actions extends StatelessWidget {
  final Map<String, dynamic> item;
  const _Actions({required this.item});

  bool _checkStatus() {
    String status = '${item['status'] ?? ''}'.toLowerCase();
    return status != 'na' && status != 'finished' && status != 'cancelled';
  }

  @override
  Widget build(BuildContext context) {
    final showActions = _checkStatus();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.content_copy, size: 18),
          onPressed: () {
            debugPrint('Copy item: ${item['_id']}');
          },
          tooltip: 'Copy',
        ),
        if (showActions) ...[
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 18),
            color: Colors.green,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HCProcessPage(workOrderId: item['_id']),
                ),
              );
            },
            tooltip: 'Start Process',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.red,
            onPressed: () {
              debugPrint('Cancel order: ${item['_id']}');
            },
            tooltip: 'Cancel',
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: Colors.green,
            onPressed: () {
              debugPrint('Edit name: ${item['_id']}');
            },
            tooltip: 'Edit',
          ),
        ],
      ],
    );
  }
}

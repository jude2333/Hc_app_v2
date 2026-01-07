import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/workOrder_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../database/couch_db.dart';
import '../features/core/util.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../services/cocuchDb_service.dart';

final _workOrderTypeProvider = StateProvider<String>((ref) => 'unbilled');

final _billingSearchProvider = StateProvider<String>((ref) => '');

final _billingExpandedRowProvider = StateProvider<String?>((ref) => null);

final _billingWorkOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, type) async {
  final workOrderService = ref.read(workOrderDBServiceProvider);

  if (type == 'billed') {
    return await workOrderService.billedList('Finished', 'Billed');
  } else {
    return await workOrderService.billedList('Finished', 'Received');
  }
});

class BillingWorkOrdersPage extends ConsumerStatefulWidget {
  const BillingWorkOrdersPage({Key? key}) : super(key: key);

  @override
  ConsumerState<BillingWorkOrdersPage> createState() =>
      _BillingWorkOrdersPageState();
}

class _BillingWorkOrdersPageState extends ConsumerState<BillingWorkOrdersPage> {
  static const double totalTableWidth = 50 +
      180 +
      80 +
      60 +
      120 +
      110 +
      80 +
      100 +
      150 +
      120 +
      130 +
      80 +
      80 +
      50;

  @override
  Widget build(BuildContext context) {
    final workOrderType = ref.watch(_workOrderTypeProvider);
    final asyncWorkOrders =
        ref.watch(_billingWorkOrdersProvider(workOrderType));
    final search = ref.watch(_billingSearchProvider);
    final expandedRowId = ref.watch(_billingExpandedRowProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(workOrderType == 'billed'
            ? 'Billed Work Orders'
            : 'Unbilled Work Orders'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'unbilled', label: Text('Unbilled')),
              ButtonSegment(value: 'billed', label: Text('Billed')),
            ],
            selected: {workOrderType},
            onSelectionChanged: (Set<String> newSelection) {
              ref.read(_workOrderTypeProvider.notifier).state =
                  newSelection.first;
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: asyncWorkOrders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (workOrders) {
          final filtered = search.isEmpty
              ? workOrders
              : Util.search(workOrders, search.toLowerCase());

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
                  onChanged: (v) =>
                      ref.read(_billingSearchProvider.notifier).state = v,
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
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade400, width: 2),
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
                              _buildHeaderCell('Total (₹)', width: 100),
                              _buildHeaderCell('Assigned', width: 150),
                              _buildHeaderCell('Tech. Status', width: 120),
                              _buildHeaderCell('Server Status', width: 130),
                              _buildHeaderCell('Actions', width: 80),
                              _buildHeaderCell('Send', width: 80),
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
        },
      ),
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
                _buildCell('${item['total'] ?? ''}', width: 100),
                _buildCell('${item['assigned_to'] ?? ''}', width: 150),
                _buildCell('',
                    width: 120,
                    child: _StatusChip(status: '${item['status'] ?? ''}')),
                _buildCell('', width: 130, child: _ServerChip(item: item)),
                _buildCell('',
                    width: 80, child: _ActionButton(item: item, ref: ref)),
                _buildCell('',
                    width: 80, child: _SendButton(item: item, ref: ref)),
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

      if (isExpanded) {
        allRows.add(
          SizedBox(
            width: totalTableWidth,
            child: _ExpandedRowContent(item: item, tableWidth: totalTableWidth),
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
    final current = ref.read(_billingExpandedRowProvider);
    ref.read(_billingExpandedRowProvider.notifier).state =
        current == itemId ? null : itemId;
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
              style: const TextStyle(fontSize: 10, color: Colors.red),
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
  const _StatusChip({required this.status});

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
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: _color().withOpacity(.15),
      labelStyle: TextStyle(color: _color()),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ServerChip extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ServerChip({required this.item});

  Color _color() {
    final s = '${item['server_status']}'.toLowerCase();
    if (s == 'billed') return Colors.green;
    if (s == 'unbilled' || s == 'received') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final status = item['server_status'] == 'Received'
        ? 'Unbilled'
        : '${item['server_status']}';
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 11)),
      backgroundColor: _color().withOpacity(.15),
      labelStyle: TextStyle(color: _color()),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ActionButton extends ConsumerWidget {
  final Map<String, dynamic> item;
  final WidgetRef ref;
  const _ActionButton({required this.item, required this.ref});

  bool _checkStatus() {
    final status = item['status'];
    final serverStatus = item['server_status'];
    if (status == 'NA' || status == 'cancelled') return false;
    return status == 'Finished' && serverStatus == 'Received';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_checkStatus()) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
      onPressed: () => _showBillDialog(context, ref),
      tooltip: 'Bill Order',
    );
  }

  void _showBillDialog(BuildContext context, WidgetRef ref) {
    final billNumberController = TextEditingController();
    final labNumberController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.orange,
          child: const Text(
            'Enter Billing Details',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: billNumberController,
                decoration: const InputDecoration(
                  labelText: 'Bill Number',
                  hintText: 'Bill Number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Bill Number is required';
                  if (v.length <= 12)
                    return 'Bill Number Must Be Greater Than 12 Characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: labNumberController,
                decoration: const InputDecoration(
                  labelText: 'Lab Number',
                  hintText: 'Lab Number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Lab Number is required';
                  if (v.length <= 8)
                    return 'Lab Number Must Be Greater Than 8 Characters';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _doBillRegister(
                  context,
                  ref,
                  billNumberController.text.toUpperCase(),
                  labNumberController.text,
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _doBillRegister(
    BuildContext context,
    WidgetRef ref,
    String billNumber,
    String labNumber,
  ) async {
    try {
      final workOrderService = ref.read(workOrderDBServiceProvider);

      item['server_status'] = 'Billed';
      item['bill_number'] = billNumber;
      item['lab_number'] = labNumber;

      await _updateBillingInfo(ref);

      final result = await workOrderService.doUpdate2(item);

      if (result == 'OK' && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        ref.invalidate(_billingWorkOrdersProvider);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $result'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateBillingInfo(WidgetRef ref) async {
    try {
      final storage = ref.read(storageServiceProvider);
      final couch = ref.read(couchDBServiceProvider);

      Dio? billingDb;
      try {
        billingDb = await couch.getDB('andrsn_billing');
      } catch (e) {
        debugPrint('⚠️ Could not connect to billing DB: $e');
        return;
      }

      String vDate = item['appointment_date'] ?? '';
      if (vDate.isEmpty) {
        debugPrint('⚠️ No appointment date found');
        return;
      }

      vDate = _convertDateFormat(vDate);

      final billNo = item['bill_number']?.toString().trim() ?? '';
      if (billNo.isEmpty) {
        debugPrint('⚠️ No bill number found');
        return;
      }

      final id = 'billing:$vDate:$billNo';

      debugPrint('🔍 Looking for billing doc: $id');

      try {
        final response = await billingDb.get('/$id');

        if (response.statusCode == 200 && response.data != null) {
          final billingDoc = Map<String, dynamic>.from(response.data);

          debugPrint('✅ Found billing doc: $id');

          if (billingDoc['status_in_number'] != null) {
            item['status_in_number'] = billingDoc['status_in_number'];
          }
          if (billingDoc['report_status'] != null) {
            item['report_status'] = billingDoc['report_status'];
          }
          if (billingDoc['report_path'] != null) {
            item['report_path'] = billingDoc['report_path'];
          }

          if (billingDoc['bill_details'] != null) {
            try {
              final billDetails = billingDoc['bill_details'];
              final billedBy = billDetails['BillUser']?.toString() ?? '';
              final billedTime = billDetails['VisitDate']?.toString() ?? '';

              String formattedTime = billedTime;
              if (billedTime.isNotEmpty) {
                try {
                  final dt = DateTime.parse(billedTime);
                  formattedTime = DateFormat('MMMM dd, h:mm a').format(dt);
                } catch (e) {
                  debugPrint('⚠️ Error parsing date: $e');
                  formattedTime = billedTime;
                }
              }

              if (billedBy.isNotEmpty) {
                final workorderBilled =
                    '$formattedTime-$billedBy- Work Order Billed';
                if (item['time_line'] == null) {
                  item['time_line'] = [];
                }
                (item['time_line'] as List).add(workorderBilled);
              }
            } catch (e) {
              debugPrint('⚠️ Error processing bill details: $e');
            }
          }

          try {
            billingDoc['doc_id'] = item['_id'];
            final docDbs = storage.getFromSession('doc_dbs');
            final tenantName = Util.resolveName(docDbs);
            if (tenantName.isNotEmpty) {
              billingDoc['tenant_db_name'] = tenantName;
            }

            await billingDb.put('/$id', data: billingDoc);
            debugPrint('✅ Successfully updated billing doc: $id');
          } catch (e) {
            debugPrint('⚠️ Error updating billing doc: $id > $e');
          }
        } else {
          debugPrint('⚠️ Billing doc returned status: ${response.statusCode}');
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          debugPrint(
              'ℹ️ Billing doc not found: $id (this is OK, may not exist yet)');
        } else {
          debugPrint('⚠️ Dio error fetching billing doc: ${e.message}');
        }
      } catch (e) {
        debugPrint('⚠️ Error accessing billing doc: $id > $e');
      }
    } catch (e) {
      debugPrint('❌ Error in _updateBillingInfo: $e');
    }
  }

  String _convertDateFormat(String date) {
    try {
      debugPrint('📅 Converting date: $date');

      if (date.isEmpty) return date;

      date = date.trim();

      if (date.contains('-')) {
        final parts = date.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            debugPrint('✅ Date already in YYYY-MM-DD format: $date');
            return date;
          } else if (parts[0].length <= 2 && parts[2].length == 4) {
            final converted = '${parts[2]}-${parts[1]}-${parts[0]}';
            debugPrint('✅ Converted DD-MM-YYYY to YYYY-MM-DD: $converted');
            return converted;
          }
        }
      }

      try {
        final dt = DateFormat('dd-MM-yyyy').parseStrict(date);
        final result = DateFormat('yyyy-MM-dd').format(dt);
        debugPrint('✅ Parsed and converted to YYYY-MM-DD: $result');
        return result;
      } catch (e) {
        try {
          final dt = DateFormat('yyyy-MM-dd').parseStrict(date);
          final result = DateFormat('yyyy-MM-dd').format(dt);
          debugPrint('✅ Already in YYYY-MM-DD: $result');
          return result;
        } catch (e2) {
          debugPrint('⚠️ Could not parse date: $date');
          return date;
        }
      }
    } catch (e) {
      debugPrint('❌ Date conversion error: $e');
      return date;
    }
  }
}

class _SendButton extends ConsumerWidget {
  final Map<String, dynamic> item;
  final WidgetRef ref;
  const _SendButton({required this.item, required this.ref});

  bool _checkStatusSend() {
    final status = item['status'];
    final serverStatus = item['server_status'];
    final sentStatus = item['sent_status'];
    if (status == 'NA' || status == 'cancelled') return false;
    return status == 'Finished' &&
        serverStatus == 'Received' &&
        sentStatus != 'sent';
  }

  bool _checkStatusChip() {
    final status = item['status'];
    final serverStatus = item['server_status'];
    final sentStatus = item['sent_status'];
    if (status == 'NA' || status == 'cancelled') return false;
    return status == 'Finished' &&
        serverStatus == 'Received' &&
        sentStatus == 'sent';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_checkStatusSend()) {
      return IconButton(
        icon: const Icon(Icons.send, size: 18, color: Colors.green),
        onPressed: () => _showConfirmSendDialog(context, ref),
        tooltip: 'Send',
      );
    } else if (_checkStatusChip()) {
      return Chip(
        label: const Text('sent', style: TextStyle(fontSize: 10)),
        backgroundColor: Colors.blue.withOpacity(0.15),
        labelStyle: const TextStyle(color: Colors.blue),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    return const SizedBox.shrink();
  }

  void _showConfirmSendDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.orange.shade100,
          child: const Text('Confirmation'),
        ),
        content: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Are you sure you want to send?')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendConfirmedItem(context, ref);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendConfirmedItem(BuildContext context, WidgetRef ref) async {
    try {
      final storage = ref.read(storageServiceProvider);
      final workOrderService = ref.read(workOrderDBServiceProvider);

      final createdBy = storage.getFromSession('logged_in_emp_id');
      final testItems = item['test_items'] as List? ?? [];
      int age = int.tryParse(item['age']?.toString() ?? '0') ?? 0;

      final data = {
        'patient': {
          'firstName': item['name'],
          'lastName': 'null',
          'age': age,
          'period': 3,
          'mobileNumber': item['mobile'],
          'addressLine1': item['address'],
          'postalCode': item['pincode'],
        },
        'clientName': 'null',
        'clientId': 0,
        'investigations': testItems
            .map((test) => {
                  'investigationId': test['invest_id'],
                  'investigationName': test['invest_name'],
                  'amount': test['base_cost'],
                  'discount': 0,
                })
            .toList(),
        'payments': [
          {'amount': item['amount_received']},
        ],
        'createdBy': createdBy,
        'remarks': item['remarks'],
      };

      final dio = Dio();
      final response = await dio.post(
        '/api',
        data: jsonEncode(data),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-static-key':
                'oxJvBOWYwwByrHlmaf/7tQsy5V7X9Q2Bez8rCeVMeP073A07UzBajHu9S+1DTQAJ',
          },
        ),
      );

      if (response.data == 'SUCCESS') {
        item['sent_status'] = 'sent';
        item['sent_status_updated_by'] =
            storage.getFromSession('logged_in_emp_name');
        item['sent_status_updated_at'] = Util.gettime();

        await workOrderService.doUpdate2(item);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sent Successfully'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(_billingWorkOrdersProvider);
        }
      } else {
        throw Exception('Failed to send data');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ExpandedRowContent extends StatelessWidget {
  final Map<String, dynamic> item;
  final double tableWidth;
  const _ExpandedRowContent({required this.item, required this.tableWidth});

  @override
  Widget build(BuildContext context) {
    final testItems = item['test_items'] as List? ?? [];

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
          _buildInfoRow('Address', '${item['address'] ?? ''}'),
          _buildInfoRow('Pincode', '${item['pincode'] ?? ''}'),
          _buildInfoRow('Ref By', 'Dr. ${item['doctor_name'] ?? ''}'),
          if (item['pres_photo'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Prescription: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ActionChip(
                  label: Text(Util.getName(item['pres_photo']),
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.blue.withOpacity(0.15),
                  labelStyle: const TextStyle(color: Colors.blue),
                  onPressed: () {
                    debugPrint('Download prescription: ${item['pres_photo']}');
                  },
                ),
              ],
            ),
          ],
          if (item['process'] != null) ...[
            const SizedBox(height: 8),
            _buildProcessSection(item['process']),
          ],
          const SizedBox(height: 16),
          const Text('Test Items:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowHeight: 40,
              dataRowHeight: 36,
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
              columns: const [
                DataColumn(
                    label: Text('Dept. Id',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Dept. Name',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Investigation Id',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Investigation Name',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Base Cost',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Min. Cost',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold))),
              ],
              rows: testItems.map<DataRow>((test) {
                return DataRow(cells: [
                  DataCell(Text('${test['dept_id'] ?? ''}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${test['dept_name'] ?? ''}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${test['invest_id'] ?? ''}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${test['invest_name'] ?? ''}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${test['base_cost'] ?? ''}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text('${test['min_cost'] ?? ''}',
                      style: const TextStyle(fontSize: 11))),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ₹${item['total'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildProcessSection(Map<String, dynamic> process) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (process['fifth_step'] != null)
          Row(
            children: [
              const Text('Prescription Photo: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ActionChip(
                label: Text(_getPrescrptionFileNames(process['fifth_step']),
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.blue.withOpacity(0.15),
                labelStyle: const TextStyle(color: Colors.blue),
                onPressed: () {
                  debugPrint(
                      'Download prescription photos: ${process['fifth_step']}');
                },
              ),
            ],
          ),
        if (process['second_step'] != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Proforma Invoice: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ActionChip(
                label: const Text('Proforma Invoice',
                    style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.blue.withOpacity(0.15),
                labelStyle: const TextStyle(color: Colors.blue),
                onPressed: () {
                  debugPrint('Download proforma: ${process['second_step']}');
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _getPrescrptionFileNames(dynamic name) {
    final nameStr = name.toString();
    final aName = nameStr.contains(',') ? nameStr.split(',') : [nameStr];
    if (aName.length > 1) {
      return '${aName.length} files.';
    }
    return Util.getName(nameStr);
  }
}

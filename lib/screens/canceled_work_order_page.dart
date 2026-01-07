import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/workOrder_service.dart';
import '../features/core/util.dart';

final _canceledDateProvider = StateProvider<String>((ref) {
  return Util.getWeekDay(0);
});

final _canceledWorkOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, date) async {
  final service = ref.read(workOrderDBServiceProvider);

  final formattedDate = _parseWeekDayToDate(date);
  return await service.getCanceledWorkOrders(formattedDate);
});

String _parseWeekDayToDate(String weekDay) {
  try {
    final parts = weekDay.split(' ');
    if (parts.length >= 4) {
      final day = int.parse(parts[1]);
      final month = _getMonthNumber(parts[2]);
      final year = int.parse(parts[3]);
      return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
  } catch (e) {
    debugPrint('Error parsing date: $e');
  }
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
}

int _getMonthNumber(String monthName) {
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12
  };
  return months[monthName] ?? 1;
}

class CanceledWorkOrderPage extends ConsumerStatefulWidget {
  const CanceledWorkOrderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CanceledWorkOrderPage> createState() =>
      _CanceledWorkOrderPageState();
}

class _CanceledWorkOrderPageState extends ConsumerState<CanceledWorkOrderPage> {
  final List<String> _suitableDates = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
  }

  void _initializeDates() {
    _suitableDates.clear();
    _suitableDates.add(Util.getWeekDay(1));
    _suitableDates.add(Util.getWeekDay(0));
    _suitableDates.add(Util.getWeekDay(-1));
    _suitableDates.add(Util.getWeekDay(-2));
    _suitableDates.add(Util.getWeekDay(-3));
    _suitableDates.add(Util.getWeekDay(-4));
    _suitableDates.add(Util.getWeekDay(-5));
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(_canceledDateProvider);
    final asyncWorkOrders =
        ref.watch(_canceledWorkOrdersProvider(selectedDate));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.orange),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Canceled Work Order',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: selectedDate,
              decoration: const InputDecoration(
                labelText: 'Choose Date',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _suitableDates.map((date) {
                return DropdownMenuItem(
                  value: date,
                  child: Text(date),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(_canceledDateProvider.notifier).state = value;
                }
              },
            ),
          ),
          Expanded(
            child: asyncWorkOrders.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text('Loading... Please wait'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(_canceledWorkOrdersProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (workOrders) {
                if (workOrders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'No cancelled work orders for this date',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return _CanceledWorkOrderTable(workOrders: workOrders);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CanceledWorkOrderTable extends StatefulWidget {
  final List<Map<String, dynamic>> workOrders;

  const _CanceledWorkOrderTable({required this.workOrders});

  @override
  State<_CanceledWorkOrderTable> createState() =>
      _CanceledWorkOrderTableState();
}

class _CanceledWorkOrderTableState extends State<_CanceledWorkOrderTable> {
  String? _expandedRowId;

  static const double totalTableWidth =
      50 + 180 + 80 + 60 + 120 + 110 + 80 + 120 + 150 + 50;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400, width: 2),
                ),
              ),
              child: Row(
                children: [
                  _buildHeaderCell('S No', width: 50),
                  _buildHeaderCell('Name', width: 180),
                  _buildHeaderCell('Gender', width: 80),
                  _buildHeaderCell('Age', width: 60),
                  _buildHeaderCell('Mobile', width: 120),
                  _buildHeaderCell('Date', width: 110),
                  _buildHeaderCell('Time', width: 80),
                  _buildHeaderCell('Tech. Status', width: 120),
                  _buildHeaderCell('Assigned To', width: 150),
                  _buildHeaderCell('', width: 50),
                ],
              ),
            ),
            ..._buildRows(),
          ],
        ),
      ),
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

  Widget _buildCell(String text, {required double width, Widget? child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      child: child ?? Text(text, overflow: TextOverflow.ellipsis),
    );
  }

  List<Widget> _buildRows() {
    List<Widget> allRows = [];

    for (int i = 0; i < widget.workOrders.length; i++) {
      final item = widget.workOrders[i];
      final itemId = item['_id']?.toString() ?? i.toString();
      final isExpanded = _expandedRowId == itemId;

      allRows.add(
        InkWell(
          onTap: () => _toggleExpand(itemId),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                _buildCell('${i + 1}', width: 50),
                _buildCell('', width: 180, child: _buildNameCell(item)),
                _buildCell('${item['gender'] ?? ''}', width: 80),
                _buildCell('${item['age'] ?? ''}', width: 60),
                _buildCell('${item['mobile'] ?? ''}', width: 120),
                _buildCell('${item['appointment_date'] ?? ''}', width: 110),
                _buildCell('${item['appointment_time'] ?? ''}', width: 80),
                _buildCell('',
                    width: 120, child: _buildStatusChip(item['status'])),
                _buildCell('${item['assigned_to'] ?? ''}', width: 150),
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
            child: _buildExpandedContent(item),
          ),
        );
      }
    }

    return allRows;
  }

  void _toggleExpand(String itemId) {
    setState(() {
      _expandedRowId = _expandedRowId == itemId ? null : itemId;
    });
  }

  Widget _buildNameCell(Map<String, dynamic> item) {
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
        ),
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              flags.join(' '),
              style: const TextStyle(fontSize: 10, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(dynamic status) {
    final statusStr = status?.toString() ?? '';
    return Chip(
      label: Text(statusStr),
      backgroundColor: _getStatusColor(statusStr).withOpacity(0.15),
      labelStyle: TextStyle(
        color: _getStatusColor(statusStr),
        fontSize: 12,
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s.startsWith('un')) return Colors.red;
    if (s == 'assigned') return Colors.blue;
    if (s == 'cancelled') return Colors.grey;
    if (s == 'finished') return Colors.green;
    if (s == 'billed') return Colors.green;
    if (s == 'unbilled') return Colors.red;
    if (s == 'waiting') return Colors.blue;
    return Colors.orange;
  }

  Widget _buildExpandedContent(Map<String, dynamic> item) {
    return Container(
      width: totalTableWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          left: BorderSide(color: Colors.orange, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: totalTableWidth - 32,
            child: _buildInfoSection(item),
          ),
          const SizedBox(height: 12),
          if (item['cancel_reason'] != null) ...[
            _buildCancellationReason(item),
            const SizedBox(height: 12),
          ],
          if (item['pres_photo'] != null) ...[
            _buildPrescriptionSection(item),
            const SizedBox(height: 12),
          ],
          if (item['remarks'] != null) ...[
            _buildRemarksSection(item),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildInfoItem('Address', '${item['address'] ?? 'N/A'}'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem('Pincode', '${item['pincode'] ?? 'N/A'}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildInfoItem(
                  'Additional Info', '${item['free_text'] ?? 'N/A'}'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem('Email', '${item['email'] ?? 'N/A'}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildInfoItem('Ref. By.', _getRefBy(item)),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  String _getRefBy(Map<String, dynamic> item) {
    if (item['b2b_client_id'] != null) {
      return 'B2B: ${item['b2b_client_name'] ?? ''}';
    }
    return 'Dr. ${item['doctor_name'] ?? ''}';
  }

  Widget _buildCancellationReason(Map<String, dynamic> item) {
    return Chip(
      avatar: const Icon(Icons.cancel, size: 16, color: Colors.red),
      label: Text(
          'Cancellation Reason: ${item['cancel_reason'] ?? 'Reason Not Given'}'),
      backgroundColor: Colors.red.withOpacity(0.15),
      labelStyle: const TextStyle(color: Colors.red),
    );
  }

  Widget _buildPrescriptionSection(Map<String, dynamic> item) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Chip(
          label: Text('Prescription:'),
          backgroundColor: Color(0xFFFFE0E0),
          labelStyle: TextStyle(color: Colors.red),
        ),
        ActionChip(
          label: Text(_getFileName(item['pres_photo'])),
          backgroundColor: Colors.blue.withOpacity(0.15),
          labelStyle: const TextStyle(color: Colors.blue),
          onPressed: () {
            debugPrint('Download prescription: ${item['pres_photo']}');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Prescription download coming soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRemarksSection(Map<String, dynamic> item) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Chip(
          label: Text('Remarks'),
          backgroundColor: Color(0xFFFFE0CC),
          labelStyle: TextStyle(color: Colors.orange),
        ),
        Text('${item['remarks']}'),
      ],
    );
  }

  String _getFileName(dynamic filePath) {
    if (filePath == null) return '';
    String pathStr = filePath.toString();
    if (pathStr.contains('/')) {
      return pathStr.substring(pathStr.lastIndexOf('/') + 1);
    }
    return pathStr;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/workOrder_service.dart';
import '../services/postgresService.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../features/core/util.dart';

// Providers
final _monthWiseProvider = StateProvider<bool>((ref) => false);
final _selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _searchProvider = StateProvider<String>((ref) => '');

// Technicians provider
final _techniciansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbService = ref.read(postgresServiceProvider);
  final result = await dbService.getTechnicians();
  if (result is List) {
    return List<Map<String, dynamic>>.from(result);
  }
  return [];
});

// Tech engagements provider
final _techEngagementsProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    ({DateTime date, bool monthWise, List<Map<String, dynamic>> techs})>(
  (ref, params) async {
    final workOrderService = ref.read(workOrderDBServiceProvider);

    String startDate, endDate;
    bool local = true;

    if (params.monthWise) {
      // Month wise
      startDate = DateFormat('yyyy-MM-dd').format(
        DateTime(params.date.year, params.date.month, 1),
      );
      endDate = DateFormat('yyyy-MM-dd').format(
        DateTime(params.date.year, params.date.month + 1, 0),
      );
      local = false; // Always fetch from remote for month wise
    } else {
      // Day wise
      startDate = DateFormat('yyyy-MM-dd').format(params.date);
      endDate = '';

      // Check if we should use local or remote
      final aggData =
          await workOrderService.getAggregateView(startDate, '', true);
      if (aggData.isNotEmpty) {
        final assigned =
            Util.parseInt(aggData[0]['total_assigned']?.toString() ?? '0');
        if (assigned == 0) {
          local = false;
        }
      }
    }

    debugPrint('Fetching tech engagement from local: $local');
    return await workOrderService.getTechEngagements(
      startDate,
      endDate,
      params.techs,
      local,
    );
  },
);

// Aggregate view provider
final _aggregateViewProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({DateTime date, bool monthWise})>(
  (ref, params) async {
    final workOrderService = ref.read(workOrderDBServiceProvider);

    String startDate, endDate;
    bool local = true;

    if (params.monthWise) {
      startDate = DateFormat('yyyy-MM-dd').format(
        DateTime(params.date.year, params.date.month, 1),
      );
      endDate = DateFormat('yyyy-MM-dd').format(
        DateTime(params.date.year, params.date.month + 1, 0),
      );
      local = false;
    } else {
      startDate = DateFormat('yyyy-MM-dd').format(params.date);
      endDate = '';

      // Check local first
      final aggData =
          await workOrderService.getAggregateView(startDate, '', true);
      if (aggData.isNotEmpty) {
        final assigned =
            Util.parseInt(aggData[0]['total_assigned']?.toString() ?? '0');
        if (assigned == 0) {
          local = false;
        } else {
          return aggData;
        }
      }
    }

    return await workOrderService.getAggregateView(startDate, endDate, local);
  },
);

class TechEngagementPage extends ConsumerStatefulWidget {
  const TechEngagementPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TechEngagementPage> createState() => _TechEngagementPageState();
}

class _TechEngagementPageState extends ConsumerState<TechEngagementPage> {
  String? _expandedTechId;

  @override
  Widget build(BuildContext context) {
    final monthWise = ref.watch(_monthWiseProvider);
    final selectedDate = ref.watch(_selectedDateProvider);
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final search = ref.watch(_searchProvider);

    final techniciansAsync = ref.watch(_techniciansProvider);

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
            'Technician Engagements',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: techniciansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading technicians: $e')),
        data: (technicians) {
          if (technicians.isEmpty) {
            return const Center(child: Text('No technicians found'));
          }

          return Column(
            children: [
              // Date selector and month wise toggle
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: monthWise
                          ? _buildMonthPicker(context, ref, selectedMonth)
                          : _buildDatePicker(context, ref, selectedDate),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        const Text('Month Wise',
                            style: TextStyle(fontSize: 12)),
                        Switch(
                          value: monthWise,
                          onChanged: (value) {
                            ref.read(_monthWiseProvider.notifier).state = value;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _buildContent(
                  context,
                  ref,
                  technicians,
                  monthWise ? selectedMonth : selectedDate,
                  monthWise,
                  search,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDatePicker(
      BuildContext context, WidgetRef ref, DateTime selectedDate) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2021, 8, 1),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          ref.read(_selectedDateProvider.notifier).state = picked;
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Choose Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
      ),
    );
  }

  Widget _buildMonthPicker(
      BuildContext context, WidgetRef ref, DateTime selectedMonth) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedMonth,
          firstDate: DateTime(2021, 8, 1),
          lastDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.year,
        );
        if (picked != null) {
          ref.read(_selectedMonthProvider.notifier).state = picked;
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Choose a Month',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(DateFormat('yyyy-MM').format(selectedMonth)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> technicians,
    DateTime date,
    bool monthWise,
    String search,
  ) {
    final engagementsAsync = ref.watch(_techEngagementsProvider((
      date: date,
      monthWise: monthWise,
      techs: technicians,
    )));

    final aggregateAsync = ref.watch(_aggregateViewProvider((
      date: date,
      monthWise: monthWise,
    )));

    return engagementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (engagements) {
        final filtered = search.isEmpty
            ? engagements
            : Util.search(engagements, search.toLowerCase());

        return SingleChildScrollView(
          child: Column(
            children: [
              // Aggregate section
              aggregateAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
                error: (e, st) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading aggregates: $e'),
                ),
                data: (aggregates) => _buildAggregateSection(aggregates),
              ),

              // Search bar and tech engagement table
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // Debounce search
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            ref.read(_searchProvider.notifier).state = value;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Tech engagement table
                    _buildTechTable(context, ref, filtered, monthWise),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAggregateSection(List<Map<String, dynamic>> aggregates) {
    if (aggregates.isEmpty) return const SizedBox.shrink();

    final data = aggregates[0];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Text(
              'Aggregates',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 0, // Hide header since we have column names
              dataRowHeight: 48,
              columns: const [
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
                DataColumn(label: SizedBox.shrink()),
              ],
              rows: [
                // Header row
                DataRow(
                  color: MaterialStateProperty.all(Colors.grey.shade200),
                  cells: const [
                    DataCell(Text('Assigned',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('Cancelled',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('Finished',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('Pending',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('Cash',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('GPay',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('HC Charges',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('Total Collected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text('Total Received',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
                // Data row
                DataRow(cells: [
                  DataCell(Text('${data['total_assigned'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['total_cancelled'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['total_finished'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['total_pending'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['cash'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['gpay'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['hc_charges'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['total_amount'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${data['amount_collected'] ?? 0}',
                      style: const TextStyle(fontSize: 12))),
                ]),
              ],
            ),
          ),
          // Footer banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Text(
                  'Total Cases Excluding Glucose(PP)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${data['total_accounted'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechTable(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> engagements,
    bool monthWise,
  ) {
    return Column(
      children: _buildTechRows(context, ref, engagements, monthWise),
    );
  }

  List<Widget> _buildTechRows(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> engagements,
    bool monthWise,
  ) {
    List<Widget> widgets = [];

    for (final tech in engagements) {
      final techId = tech['_id']?.toString() ?? '';
      final isExpanded = _expandedTechId == techId;
      final assignedList = tech['assigned_list'] as List? ?? [];

      // Main tech row
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedTechId = isExpanded ? null : techId;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${tech['name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildStatChip(
                          'Assigned', '${tech['assigned'] ?? 0}', Colors.blue),
                      const SizedBox(width: 4),
                      _buildStatChip('Cancelled', '${tech['cancelled'] ?? 0}',
                          Colors.grey),
                      const SizedBox(width: 4),
                      _buildStatChip(
                          'Finished', '${tech['finished'] ?? 0}', Colors.green),
                      const SizedBox(width: 4),
                      _buildStatChip(
                          'Pending', '${tech['pending'] ?? 0}', Colors.orange),
                      const SizedBox(width: 8),
                      Text('Till: ${tech['time_till'] ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              'Cash: ${tech['cash'] ?? 0} | GPay: ${tech['gpay'] ?? 0}',
                              style: const TextStyle(fontSize: 11)),
                          Text(
                              'Total: ${tech['amount'] ?? 0} | Received: ${tech['amount_collected'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
              // Expanded content
              if (isExpanded && assignedList.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: _buildExpandedTechContent(
                      context, ref, assignedList, monthWise),
                ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildExpandedTechContent(
    BuildContext context,
    WidgetRef ref,
    List assignedList,
    bool monthWise,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowColor: MaterialStateProperty.all(Colors.orange.shade50),
        dataRowHeight: 56,
        columns: const [
          DataColumn(
              label: Text('Patient Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Gender',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Age',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Mobile',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('HC Charges',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Amount',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(
              label: Text('Accept Remittance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
        rows: assignedList.map<DataRow>((item) {
          final status = item['status']?.toString() ?? '';
          final paymentMethod = item['payment_method']?.toString() ?? '';
          final amountReceived = item['amount_received']?.toString() ?? 'NA';

          return DataRow(cells: [
            DataCell(Text(item['name']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(item['gender']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(item['age']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(item['mobile']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(
              monthWise
                  ? (item['appointment_date']?.toString() ?? '')
                  : (item['appointment_time']?.toString() ?? ''),
              style: const TextStyle(fontSize: 12),
            )),
            DataCell(_buildStatusChip(status)),
            DataCell(Text(item['hc_charges']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(
                Text(amountReceived, style: const TextStyle(fontSize: 12))),
            DataCell(_buildRemittanceCell(
                context, ref, item, paymentMethod, status)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.orange;
    final s = status.toLowerCase().trim();
    if (s.startsWith('un')) {
      color = Colors.red;
    } else if (s == 'assigned') {
      color = Colors.blue;
    } else if (s == 'cancelled') {
      color = Colors.grey;
    } else if (s == 'finished') {
      color = Colors.green;
    }

    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildRemittanceCell(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    String paymentMethod,
    String status,
  ) {
    if (paymentMethod == 'gpay') {
      return Chip(
        label: Text('GPay ${item['gpay_ref'] ?? ''}',
            style: const TextStyle(fontSize: 10)),
        backgroundColor: Colors.blue.withOpacity(0.15),
        labelStyle: const TextStyle(color: Colors.blue),
      );
    } else if (_checkCashPayment(item, status, paymentMethod)) {
      if (item['remittance'] == true) {
        final acceptRemittance = item['accept_remittance'] ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              acceptRemittance ? 'Received' : 'Accept',
              style: const TextStyle(fontSize: 10),
            ),
            Switch(
              value: acceptRemittance,
              onChanged: (value) =>
                  _handleRemittanceChange(context, ref, item, value),
              activeColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        );
      } else {
        return const Text('Not Remitted', style: TextStyle(fontSize: 10));
      }
    } else {
      return const Text('Credit Client', style: TextStyle(fontSize: 10));
    }
  }

  bool _checkCashPayment(
      Map<String, dynamic> item, String status, String paymentMethod) {
    if (status == 'Finished') {
      if (paymentMethod == 'cash') {
        final amount =
            Util.parseInt(item['amount_received']?.toString() ?? '0');
        if (amount > 0) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _handleRemittanceChange(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    bool value,
  ) async {
    try {
      final workOrderService = ref.read(workOrderDBServiceProvider);
      final storage = ref.read(storageServiceProvider);

      // Get the full document
      final id = item['_id']?.toString() ?? '';
      if (id.isEmpty) return;

      final doc = await workOrderService.getWithIdRemote(id);
      if (doc == null) {
        throw Exception('Work order not found');
      }

      // Update remittance status
      doc['accept_remittance'] = value;

      // Update timeline
      final timeStamp = Util.gettime();
      final user = storage.getFromSession('logged_in_emp_name');
      final newTl = value
          ? '$timeStamp - $user - Remittance Accepted.'
          : '$timeStamp - $user - Remittance Cancelled.';

      if (doc['time_line'] == null) {
        doc['time_line'] = [];
      }
      (doc['time_line'] as List).add(newTl);

      // Save
      final result = await workOrderService.doUpdate2(doc);

      if (result == 'OK') {
        // Update local item
        item['accept_remittance'] = value;

        // Refresh the data
        ref.invalidate(_techEngagementsProvider);
        ref.invalidate(_aggregateViewProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value
                  ? 'Remittance Accepted Successfully.'
                  : 'Remittance Cancelled.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result);
      }
    } catch (e) {
      debugPrint('Error updating remittance: $e');
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
}

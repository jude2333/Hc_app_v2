import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anderson_crm_flutter/services/dashboard_service.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'widgets/dashboard_widgets.dart';

class WeeklyReportTab extends ConsumerStatefulWidget {
  const WeeklyReportTab({super.key});

  @override
  ConsumerState<WeeklyReportTab> createState() => _WeeklyReportTabState();
}

class _WeeklyReportTabState extends ConsumerState<WeeklyReportTab>
    with AutomaticKeepAliveClientMixin {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now().subtract(const Duration(days: 1)),
  );
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  List<Map<String, dynamic>> _tableData = [];
  Map<String, dynamic>? _chartData;
  Map<String, dynamic>? _collectionChartData;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final startDate = _selectedDateRange.start;
      final year = startDate.year.toString();
      final docId = "daily_$year";

      final dashboardService = ref.read(dashboardServiceProvider);
      final doc = await dashboardService.getOne(docId);

      if (doc != null && doc['data'] != null) {
        final data = doc['data'] as Map<String, dynamic>;

        _tableData = [];
        List<String> labels = [];
        List<int> assigned = [], finished = [], cancelled = [], pending = [];
        List<int> collection = [],
            received = [],
            credit = [],
            b2b = [],
            trial = [];

        int tAssigned = 0, tFinished = 0, tCancelled = 0, tPending = 0;
        double tCollection = 0,
            tReceived = 0,
            tCredit = 0,
            tB2b = 0,
            tTrial = 0;

        for (int i = 0; i < 7; i++) {
          final currentDate = startDate.add(Duration(days: i));
          final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
          final dayData = data[formattedDate];

          final row = {
            'label': DateFormat('MMM dd (E)').format(currentDate),
            'assigned': 0,
            'finished': 0,
            'cancelled': 0,
            'pending': 0,
            'collection': 0.0,
            'received': 0.0,
            'credit': 0.0,
            'b2b': 0.0,
            'trial': 0.0
          };

          if (dayData != null) {
            row['assigned'] = (dayData['assigned'] as num).toInt();
            row['finished'] = (dayData['finished'] as num).toInt();
            row['cancelled'] = (dayData['cancelled'] as num).toInt();
            row['pending'] = (dayData['pending'] as num).toInt();
            row['collection'] = (dayData['collection'] as num).toDouble();
            row['received'] = (dayData['received'] as num).toDouble();
            row['credit'] = (dayData['credit'] as num).toDouble();
            row['b2b'] = (dayData['b2b'] as num).toDouble();
            row['trial'] = (dayData['trial'] as num).toDouble();
          }

          _tableData.add(row);
          labels.add(DateFormat('EEE').format(currentDate));

          tAssigned += row['assigned'] as int;
          tFinished += row['finished'] as int;
          tCancelled += row['cancelled'] as int;
          tPending += row['pending'] as int;
          tCollection += row['collection'] as double;
          tReceived += row['received'] as double;
          tCredit += row['credit'] as double;
          tB2b += row['b2b'] as double;
          tTrial += row['trial'] as double;

          assigned.add(row['assigned'] as int);
          finished.add(row['finished'] as int);
          cancelled.add(row['cancelled'] as int);
          pending.add(row['pending'] as int);
          collection.add((row['collection'] as double).toInt());
          received.add((row['received'] as double).toInt());
          credit.add((row['credit'] as double).toInt());
          b2b.add((row['b2b'] as double).toInt());
          trial.add((row['trial'] as double).toInt());
        }

        _tableData.add({
          'label': 'Total',
          'assigned': tAssigned,
          'finished': tFinished,
          'cancelled': tCancelled,
          'pending': tPending,
          'collection': tCollection,
          'received': tReceived,
          'credit': tCredit,
          'b2b': tB2b,
          'trial': tTrial,
          'isTotal': true
        });

        setState(() {
          _chartData = {
            'labels': labels,
            'assigned': assigned,
            'finished': finished,
            'cancelled': cancelled,
            'pending': pending
          };
          _collectionChartData = {
            'labels': labels,
            'collection': collection,
            'received': received,
            'credit': credit,
            'b2b': b2b,
            'trial': trial
          };
          _hasLoadedOnce = true;
        });
      } else {
        _showMessage("No Data Found");
        setState(() {
          _tableData = [];
          _chartData = null;
          _collectionChartData = null;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      _showMessage("Error: $e");
      setState(() => _hasLoadedOnce = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Colors.orange)),
          child: child!),
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildDateHeader(),
          if (_isLoading && !_hasLoadedOnce)
            const Expanded(child: DashboardSkeletonLoading())
          else if (_isLoading)
            const Expanded(
                child: Center(
                    child: CircularProgressIndicator(color: Colors.orange)))
          else if (_tableData.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const DashboardSectionTitle("Detailed Report"),
                    const SizedBox(height: 12),
                    _buildDetailedTable(),
                    const SizedBox(height: 24),
                    const DashboardSectionTitle("Daily Trend"),
                    const SizedBox(height: 12),
                    if (_chartData != null) _buildCasesChart(),
                    const SizedBox(height: 24),
                    if (_collectionChartData != null) _buildCollectionChart(),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: DashboardEmptyState(
                message: "No data available",
                onRetry: _loadData,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final start = DateFormat('dd MMM').format(_selectedDateRange.start);
    final end = DateFormat('dd MMM').format(_selectedDateRange.end);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2))
      ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Selected Range",
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
            Text("$start - $end",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ]),
          InkWell(
            onTap: _selectDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade100)),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tableWidth =
            constraints.maxWidth < 1000 ? 1000 : constraints.maxWidth;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.blue,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: const [
                        _HeaderCell('Day', flex: 2),
                        _HeaderCell('Assigned', flex: 1),
                        _HeaderCell('Finished', flex: 1),
                        _HeaderCell('Cancelled', flex: 1),
                        _HeaderCell('Pending', flex: 1),
                        _HeaderCell('Total\nCollection', flex: 2),
                        _HeaderCell('Received', flex: 2),
                        _HeaderCell('Credit', flex: 2),
                        _HeaderCell('B2B', flex: 1),
                        _HeaderCell('Trial', flex: 1),
                      ],
                    ),
                  ),
                  ..._tableData.map((row) {
                    final isTotal = row['isTotal'] == true;
                    return Container(
                      decoration: BoxDecoration(
                        color: isTotal ? Colors.grey.shade50 : Colors.white,
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Row(
                        children: [
                          _DataCell(row['label'], flex: 2, isBold: isTotal),
                          _DataCell(row['assigned'].toString(),
                              flex: 1, isBold: isTotal),
                          _DataCell(row['finished'].toString(),
                              flex: 1, isBold: isTotal),
                          _DataCell(row['cancelled'].toString(),
                              flex: 1, isBold: isTotal),
                          _DataCell(row['pending'].toString(),
                              flex: 1, isBold: isTotal),
                          _DataCell(Util.formatMoney(row['collection']),
                              flex: 2, isBold: isTotal),
                          _DataCell(Util.formatMoney(row['received']),
                              flex: 2, isBold: isTotal),
                          _DataCell(Util.formatMoney(row['credit']),
                              flex: 2, isBold: isTotal),
                          _DataCell(Util.formatMoney(row['b2b']),
                              flex: 1, isBold: isTotal),
                          _DataCell(Util.formatMoney(row['trial']),
                              flex: 1, isBold: isTotal),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCasesChart() {
    return SizedBox(
      height: 350,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: _calculateMaxY(_chartData!),
            barTouchData: _buildBarTouchData(),
            titlesData:
                _buildTitlesData(_chartData!, _calculateInterval(_chartData!)),
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _calculateInterval(_chartData!),
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups:
                List.generate((_chartData!['labels'] as List).length, (index) {
              return BarChartGroupData(x: index, barsSpace: 4, barRods: [
                BarChartRodData(
                  toY: _chartData!['finished'][index].toDouble(),
                  gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter),
                  width: 10,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: _chartData!['assigned'][index].toDouble(),
                  gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter),
                  width: 10,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionChart() {
    return SizedBox(
      height: 350,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: _calculateMaxYCollection(_collectionChartData!),
            barTouchData: _buildBarTouchData(isMoney: true),
            titlesData: _buildTitlesData(_collectionChartData!,
                _calculateIntervalCollection(_collectionChartData!),
                isMoney: true),
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    _calculateIntervalCollection(_collectionChartData!),
                getDrawingHorizontalLine: (v) =>
                    FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
                (_collectionChartData!['labels'] as List).length, (index) {
              return BarChartGroupData(x: index, barsSpace: 4, barRods: [
                BarChartRodData(
                  toY: _collectionChartData!['collection'][index].toDouble(),
                  gradient: LinearGradient(
                      colors: [Colors.indigo.shade300, Colors.indigo.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter),
                  width: 12,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }

  BarTouchData _buildBarTouchData({bool isMoney = false}) => BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.blueGrey.shade800,
          getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              '${r.toY.toInt()}', const TextStyle(color: Colors.white))));
  FlTitlesData _buildTitlesData(Map<String, dynamic> data, double interval,
          {bool isMoney = false}) =>
      FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: isMoney ? 40 : 25,
                interval: interval,
                getTitlesWidget: (v, m) => v == 0
                    ? const SizedBox.shrink()
                    : Text(_formatCompactNumber(v.toInt()),
                        style:
                            TextStyle(color: Colors.black87, fontSize: 10)))),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) =>
                    (v.toInt() < (data['labels'] as List).length)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(data['labels'][v.toInt()],
                                style: const TextStyle(fontSize: 10)))
                        : const Text(''))),
      );
  double _calculateMaxY(Map d) {
    var l = [...d['assigned'], ...d['finished']].cast<int>();
    return l.isEmpty
        ? 10
        : (l.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
  }

  double _calculateMaxYCollection(Map d) {
    var l = [...d['collection']].cast<int>();
    return l.isEmpty
        ? 1000
        : (l.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
  }

  double _calculateInterval(Map d) => _calculateMaxY(d) / 5;
  double _calculateIntervalCollection(Map d) => _calculateMaxYCollection(d) / 5;
  String _formatCompactNumber(int value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: TextAlign.left,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isBold;
  const _DataCell(this.text, {required this.flex, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        textAlign: TextAlign.left,
      ),
    );
  }
}

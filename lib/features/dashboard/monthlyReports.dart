import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anderson_crm_flutter/services/dashboard_service.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'widgets/dashboard_widgets.dart';

class MonthlyReportTab extends ConsumerStatefulWidget {
  const MonthlyReportTab({super.key});

  @override
  ConsumerState<MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends ConsumerState<MonthlyReportTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedMonth = DateTime.now().subtract(const Duration(days: 30));
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
      final year = _selectedMonth.year.toString();
      final docId = "weekly_$year";

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

        final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        final lastDay =
            DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
        final startWeek = _getWeekNumber(firstDay);
        final endWeek = _getWeekNumber(lastDay);
        final adjustedEndWeek = endWeek < startWeek ? endWeek + 52 : endWeek;

        for (int i = startWeek; i <= adjustedEndWeek; i++) {
          final weekNum = i > 52 ? i - 52 : i;
          final weekKey = weekNum.toString();
          final weekData = data[weekKey];

          final row = {
            'label': 'Week-$weekNum',
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

          if (weekData != null) {
            row['assigned'] = (weekData['assigned'] as num).toInt();
            row['finished'] = (weekData['finished'] as num).toInt();
            row['cancelled'] = (weekData['cancelled'] as num).toInt();
            row['pending'] = (weekData['pending'] as num).toInt();
            row['collection'] = (weekData['collection'] as num).toDouble();
            row['received'] = (weekData['received'] as num).toDouble();
            row['credit'] = (weekData['credit'] as num).toDouble();
            row['b2b'] = (weekData['b2b'] as num).toDouble();
            row['trial'] = (weekData['trial'] as num).toDouble();
          }

          _tableData.add(row);

          tAssigned += row['assigned'] as int;
          tFinished += row['finished'] as int;
          tCancelled += row['cancelled'] as int;
          tPending += row['pending'] as int;
          tCollection += row['collection'] as double;
          tReceived += row['received'] as double;
          tCredit += row['credit'] as double;
          tB2b += row['b2b'] as double;
          tTrial += row['trial'] as double;

          labels.add('W$weekNum');
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
        _showMessage("No Data Found For Year $year");
        setState(() {
          _tableData = [];
          _chartData = null;
          _collectionChartData = null;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      _showMessage("Error loading data: $e");
      setState(() => _hasLoadedOnce = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
            data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: Colors.orange)),
            child: child!);
      },
    );

    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
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
                    const DashboardSectionTitle("Weekly Case Trend"),
                    const SizedBox(height: 12),
                    if (_chartData != null) _buildCasesChart(),
                    const SizedBox(height: 24),
                    const DashboardSectionTitle("Weekly Financial Trend"),
                    const SizedBox(height: 12),
                    if (_collectionChartData != null) _buildCollectionChart(),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: DashboardEmptyState(
                message: "No data for this month",
                onRetry: _loadData,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Selected Month",
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              Text(DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
          InkWell(
            onTap: _selectMonth,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100)),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.orange),
            ),
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
                        _HeaderCell('Week', flex: 2),
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
            barGroups: List.generate(
                (_chartData!['labels'] as List).length,
                (index) => BarChartGroupData(x: index, barsSpace: 6, barRods: [
                      BarChartRodData(
                        toY: _chartData!['finished'][index].toDouble(),
                        gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: _chartData!['assigned'][index].toDouble(),
                        gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ])),
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
                (_collectionChartData!['labels'] as List).length,
                (index) => BarChartGroupData(x: index, barRods: [
                      BarChartRodData(
                        toY: _collectionChartData!['collection'][index]
                            .toDouble(),
                        gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade300,
                              Colors.indigo.shade600
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ])),
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
                        ? Text(data['labels'][v.toInt()],
                            style: const TextStyle(fontSize: 10))
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

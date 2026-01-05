import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anderson_crm_flutter/services/dashboard_service.dart';
import 'package:anderson_crm_flutter/util.dart';
import 'widgets/dashboard_widgets.dart';

class YearlyReportTab extends ConsumerStatefulWidget {
  const YearlyReportTab({super.key});

  @override
  ConsumerState<YearlyReportTab> createState() => _YearlyReportTabState();
}

class _YearlyReportTabState extends ConsumerState<YearlyReportTab>
    with AutomaticKeepAliveClientMixin {
  int _selectedYear = DateTime.now().year;
  bool _monthwise = true;
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  List<Map<String, dynamic>> _tableData = [];
  Map<String, dynamic>? _chartData;
  Map<String, dynamic>? _collectionChartData;
  List<int> _availableYears = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() => _loadAvailableYears());
  }

  Future<void> _loadAvailableYears() async {
    try {
      final dashboardService = ref.read(dashboardServiceProvider);
      final doc = await dashboardService.getOne("yearly");

      if (doc != null && doc['data'] != null) {
        final data = doc['data'] as Map<String, dynamic>;
        final years = data.keys.map((key) => int.tryParse(key) ?? 0).toList();
        years.sort();

        setState(() {
          _availableYears = years;
          if (years.isNotEmpty) {
            _selectedYear = years.last;
          }
        });

        _loadData();
      } else {
        setState(() => _hasLoadedOnce = true);
      }
    } catch (e) {
      _showMessage("Error loading available years: $e");
      setState(() => _hasLoadedOnce = true);
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (_monthwise) {
        await _loadMonthlyData();
      } else {
        await _loadYearlyData();
      }
      setState(() => _hasLoadedOnce = true);
    } catch (e) {
      _showMessage("Error loading data: $e");
      setState(() => _hasLoadedOnce = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMonthlyData() async {
    final docId = "yearly_$_selectedYear";

    final dashboardService = ref.read(dashboardServiceProvider);
    final doc = await dashboardService.getOne(docId);

    if (doc != null && doc['data'] != null) {
      final data = doc['data'] as Map<String, dynamic>;
      final List<Map<String, dynamic>> yearData = [];
      final List<String> labels = [];
      final List<int> assigned = [],
          finished = [],
          cancelled = [],
          pending = [];
      final List<int> collection = [],
          received = [],
          credit = [],
          b2b = [],
          trial = [];

      int totalAssigned = 0,
          totalFinished = 0,
          totalCancelled = 0,
          totalPending = 0;
      int totalCollection = 0,
          totalReceived = 0,
          totalCredit = 0,
          totalB2b = 0,
          totalTrial = 0;

      for (int i = 1; i <= 12; i++) {
        final monthData = data[i.toString()];
        final monthName =
            DateFormat('MMMM').format(DateTime(_selectedYear, i, 1));

        if (monthData != null) {
          final row = {
            'label': monthName,
            'assigned': (monthData['assigned'] as num).toInt(),
            'finished': (monthData['finished'] as num).toInt(),
            'cancelled': (monthData['cancelled'] as num).toInt(),
            'pending': (monthData['pending'] as num).toInt(),
            'collection': (monthData['collection'] as num).toDouble(),
            'received': (monthData['received'] as num).toDouble(),
            'credit': (monthData['credit'] as num).toDouble(),
            'b2b': (monthData['b2b'] as num).toDouble(),
            'trial': (monthData['trial'] as num).toDouble(),
          };

          yearData.add(row);
          labels.add(DateFormat('MMM').format(DateTime(_selectedYear, i, 1)));

          totalAssigned += row['assigned'] as int;
          totalFinished += row['finished'] as int;
          totalCancelled += row['cancelled'] as int;
          totalPending += row['pending'] as int;
          totalCollection += (row['collection'] as double).toInt();
          totalReceived += (row['received'] as double).toInt();
          totalCredit += (row['credit'] as double).toInt();
          totalB2b += (row['b2b'] as double).toInt();
          totalTrial += (row['trial'] as double).toInt();

          assigned.add(row['assigned'] as int);
          finished.add(row['finished'] as int);
          cancelled.add(row['cancelled'] as int);
          pending.add(row['pending'] as int);
          collection.add((row['collection'] as double).toInt());
          received.add((row['received'] as double).toInt());
          credit.add((row['credit'] as double).toInt());
          b2b.add((row['b2b'] as double).toInt());
          trial.add((row['trial'] as double).toInt());
        } else {
          yearData.add({
            'label': monthName,
            'assigned': 0,
            'finished': 0,
            'cancelled': 0,
            'pending': 0,
            'collection': 0.0,
            'received': 0.0,
            'credit': 0.0,
            'b2b': 0.0,
            'trial': 0.0,
          });
          labels.add(DateFormat('MMM').format(DateTime(_selectedYear, i, 1)));
          assigned.add(0);
          finished.add(0);
          cancelled.add(0);
          pending.add(0);
          collection.add(0);
          received.add(0);
          credit.add(0);
          b2b.add(0);
          trial.add(0);
        }
      }

      yearData.add({
        'label': 'Total',
        'assigned': totalAssigned,
        'finished': totalFinished,
        'cancelled': totalCancelled,
        'pending': totalPending,
        'collection': totalCollection.toDouble(),
        'received': totalReceived.toDouble(),
        'credit': totalCredit.toDouble(),
        'b2b': totalB2b.toDouble(),
        'trial': totalTrial.toDouble(),
        'isTotal': true,
      });

      setState(() {
        _tableData = yearData;
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
      });
    } else {
      _showMessage("No Data Found For The Selected Year");
    }
  }

  Future<void> _loadYearlyData() async {
    final dashboardService = ref.read(dashboardServiceProvider);
    final doc = await dashboardService.getOne("yearly");

    if (doc != null && doc['data'] != null) {
      final data = doc['data'] as Map<String, dynamic>;
      final List<Map<String, dynamic>> yearData = [];
      final List<String> labels = [];
      final List<int> assigned = [],
          finished = [],
          cancelled = [],
          pending = [];
      final List<int> collection = [],
          received = [],
          credit = [],
          b2b = [],
          trial = [];

      int totalAssigned = 0,
          totalFinished = 0,
          totalCancelled = 0,
          totalPending = 0;
      int totalCollection = 0,
          totalReceived = 0,
          totalCredit = 0,
          totalB2b = 0,
          totalTrial = 0;

      final sortedKeys = data.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

      for (final yearKey in sortedKeys) {
        final yearItem = data[yearKey];
        if (yearItem != null) {
          final row = {
            'label': yearKey,
            'assigned': (yearItem['assigned'] as num).toInt(),
            'finished': (yearItem['finished'] as num).toInt(),
            'cancelled': (yearItem['cancelled'] as num).toInt(),
            'pending': (yearItem['pending'] as num).toInt(),
            'collection': (yearItem['collection'] as num).toDouble(),
            'received': (yearItem['received'] as num).toDouble(),
            'credit': (yearItem['credit'] as num).toDouble(),
            'b2b': (yearItem['b2b'] as num).toDouble(),
            'trial': (yearItem['trial'] as num).toDouble(),
          };

          yearData.add(row);
          labels.add(yearKey);

          totalAssigned += row['assigned'] as int;
          totalFinished += row['finished'] as int;
          totalCancelled += row['cancelled'] as int;
          totalPending += row['pending'] as int;
          totalCollection += (row['collection'] as double).toInt();
          totalReceived += (row['received'] as double).toInt();
          totalCredit += (row['credit'] as double).toInt();
          totalB2b += (row['b2b'] as double).toInt();
          totalTrial += (row['trial'] as double).toInt();

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
      }

      yearData.add({
        'label': 'Total',
        'assigned': totalAssigned,
        'finished': totalFinished,
        'cancelled': totalCancelled,
        'pending': totalPending,
        'collection': totalCollection.toDouble(),
        'received': totalReceived.toDouble(),
        'credit': totalCredit.toDouble(),
        'b2b': totalB2b.toDouble(),
        'trial': totalTrial.toDouble(),
        'isTotal': true,
      });

      setState(() {
        _tableData = yearData;
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
      });
    } else {
      _showMessage("No Data Found For The Selected Years");
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onMonthwiseChanged(bool value) {
    setState(() => _monthwise = value);
    _loadData();
  }

  void _onYearChanged(int? year) {
    if (year != null) {
      setState(() => _selectedYear = year);
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
          _buildHeader(),
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
                    DashboardSectionTitle(_monthwise
                        ? "Monthly Case Trend"
                        : "Yearly Case Trend"),
                    const SizedBox(height: 12),
                    if (_chartData != null) _buildCasesChart(),
                    const SizedBox(height: 24),
                    DashboardSectionTitle(_monthwise
                        ? "Monthly Financial Trend"
                        : "Yearly Financial Trend"),
                    const SizedBox(height: 12),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _monthwise ? "Monthly View" : "Yearly View",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _monthwise ? _selectedYear.toString() : "All Years",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_monthwise && _availableYears.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    underline: const SizedBox(),
                    items: _availableYears.map((year) {
                      return DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: _onYearChanged,
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 12,
                        color: _monthwise ? Colors.orange : Colors.grey,
                        fontWeight:
                            _monthwise ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Switch(
                      value: _monthwise,
                      onChanged: _onMonthwiseChanged,
                      activeTrackColor: Colors.orange.shade200,
                      thumbColor: WidgetStateProperty.all(Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
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
                      children: [
                        DashboardHeaderCell(_monthwise ? 'Month' : 'Year',
                            flex: 2),
                        const DashboardHeaderCell('Assigned', flex: 1),
                        const DashboardHeaderCell('Finished', flex: 1),
                        const DashboardHeaderCell('Cancelled', flex: 1),
                        const DashboardHeaderCell('Pending', flex: 1),
                        const DashboardHeaderCell('Total\nCollection', flex: 2),
                        const DashboardHeaderCell('Received', flex: 2),
                        const DashboardHeaderCell('Credit', flex: 2),
                        const DashboardHeaderCell('B2B', flex: 1),
                        const DashboardHeaderCell('Trial', flex: 1),
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
                          DashboardDataCell(row['label'] ?? '',
                              flex: 2, isBold: isTotal),
                          DashboardDataCell(row['assigned'].toString(),
                              flex: 1, isBold: isTotal),
                          DashboardDataCell(row['finished'].toString(),
                              flex: 1, isBold: isTotal),
                          DashboardDataCell(row['cancelled'].toString(),
                              flex: 1, isBold: isTotal),
                          DashboardDataCell(row['pending'].toString(),
                              flex: 1, isBold: isTotal),
                          DashboardDataCell(
                              Util.formatMoney(row['collection'] ?? 0),
                              flex: 2,
                              isBold: isTotal),
                          DashboardDataCell(
                              Util.formatMoney(row['received'] ?? 0),
                              flex: 2,
                              isBold: isTotal),
                          DashboardDataCell(
                              Util.formatMoney(row['credit'] ?? 0),
                              flex: 2,
                              isBold: isTotal),
                          DashboardDataCell(Util.formatMoney(row['b2b'] ?? 0),
                              flex: 1, isBold: isTotal),
                          DashboardDataCell(Util.formatMoney(row['trial'] ?? 0),
                              flex: 1, isBold: isTotal),
                        ],
                      ),
                    );
                  }),
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
              offset: const Offset(0, 4),
            ),
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
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              (_chartData!['labels'] as List).length,
              (index) => BarChartGroupData(
                x: index,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: _chartData!['finished'][index].toDouble(),
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 10,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: _chartData!['assigned'][index].toDouble(),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 10,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            ),
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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: _calculateMaxYCollection(_collectionChartData!),
            barTouchData: _buildBarTouchData(isMoney: true),
            titlesData: _buildTitlesData(
              _collectionChartData!,
              _calculateIntervalCollection(_collectionChartData!),
              isMoney: true,
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  _calculateIntervalCollection(_collectionChartData!),
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              (_collectionChartData!['labels'] as List).length,
              (index) => BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: _collectionChartData!['collection'][index].toDouble(),
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade300, Colors.indigo.shade600],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 14,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            ),
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
            '${r.toY.toInt()}',
            const TextStyle(color: Colors.white),
          ),
        ),
      );

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
                        const TextStyle(color: Colors.black87, fontSize: 10)),
          ),
        ),
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, m) =>
                (v.toInt() < (data['labels'] as List).length)
                    ? Text(data['labels'][v.toInt()],
                        style: const TextStyle(fontSize: 10))
                    : const Text(''),
          ),
        ),
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
    return value.toString();
  }
}

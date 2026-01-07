import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anderson_crm_flutter/services/dashboard_service.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'widgets/dashboard_widgets.dart';

class DailyReportTab extends ConsumerStatefulWidget {
  const DailyReportTab({super.key});

  @override
  ConsumerState<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends ConsumerState<DailyReportTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  Map<String, dynamic>? _currentDayData;
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
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final year = _selectedDate.year.toString();
      final docId = "daily_$year";

      final dashboardService = ref.read(dashboardServiceProvider);
      final doc = await dashboardService.getOne(docId);

      if (doc != null && doc['data'] != null) {
        final data = doc['data'] as Map<String, dynamic>;
        final todayData = data[formattedDate];

        if (todayData != null) {
          final updatedData = Map<String, dynamic>.from(todayData);
          updatedData['date'] = formattedDate;

          setState(() {
            _currentDayData = updatedData;
            _chartData = _prepareChartData(updatedData);
            _collectionChartData = _prepareCollectionChartData(updatedData);
            _hasLoadedOnce = true;
          });
        } else {
          setState(() {
            _currentDayData = null;
            _chartData = null;
            _collectionChartData = null;
            _hasLoadedOnce = true;
          });
          _showMessage(
              "No Data Found For ${DateFormat('dd MMM').format(_selectedDate)}");
        }
      } else {
        _showMessage("No Data Found For Year $year");
        setState(() => _hasLoadedOnce = true);
      }
    } catch (e) {
      _showMessage("Error loading data: $e");
      setState(() => _hasLoadedOnce = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _prepareChartData(Map<String, dynamic> data) {
    return {
      'labels': [DateFormat('MMM dd').format(_selectedDate)],
      'assigned': [(data['assigned'] as num).toInt()],
      'finished': [(data['finished'] as num).toInt()],
      'cancelled': [(data['cancelled'] as num).toInt()],
      'pending': [(data['pending'] as num).toInt()],
    };
  }

  Map<String, dynamic> _prepareCollectionChartData(Map<String, dynamic> data) {
    return {
      'labels': [DateFormat('MMM dd').format(_selectedDate)],
      'collection': [(data['collection'] as num).toInt()],
      'received': [(data['received'] as num).toInt()],
      'credit': [(data['credit'] as num).toInt()],
      'b2b': [(data['b2b'] as num).toInt()],
      'trial': [(data['trial'] as num).toInt()],
    };
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.orange),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
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
          else if (_currentDayData != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const DashboardSectionTitle("Overview"),
                    const SizedBox(height: 12),
                    _buildMetricsGrid(),
                    const SizedBox(height: 20),
                    const DashboardSectionTitle("Case Status"),
                    const SizedBox(height: 8),
                    if (_chartData != null) _buildCasesChart(),
                    const SizedBox(height: 20),
                    const DashboardSectionTitle("Financial Summary"),
                    const SizedBox(height: 8),
                    if (_collectionChartData != null) _buildCollectionChart(),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: DashboardEmptyState(
                message: "No data available for this date",
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEEE').format(_selectedDate),
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
              Text(DateFormat('dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
          InkWell(
            onTap: _selectDate,
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

  Widget _buildMetricsGrid() {
    final data = _currentDayData!;
    return Column(
      children: [
        Row(
          children: [
            _buildMetricCard("Assigned", data['assigned'], Colors.blue),
            const SizedBox(width: 12),
            _buildMetricCard("Finished", data['finished'], Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricCard("Pending", data['pending'], Colors.orange),
            const SizedBox(width: 12),
            _buildMetricCard("Cancelled", data['cancelled'], Colors.red),
          ],
        ),
        const SizedBox(height: 20),
        _buildFinancialCard(
            "Total Collection", data['collection'], Colors.indigo,
            isMoney: true),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricCard("Received", data['received'], Colors.teal,
                isMoney: true),
            const SizedBox(width: 12),
            _buildMetricCard("Credit", data['credit'], Colors.purple,
                isMoney: true),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricCard("B2B", data['b2b'], Colors.brown, isMoney: true),
            const SizedBox(width: 12),
            _buildMetricCard("Trial", data['trial'], Colors.grey,
                isMoney: true),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, dynamic value, Color color,
      {bool isMoney = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isMoney
                  ? Util.formatMoney((value as num).toDouble())
                  : value.toString(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String title, dynamic value, Color color,
      {bool isMoney = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                isMoney
                    ? Util.formatMoney((value as num).toDouble())
                    : value.toString(),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.wallet, color: Colors.white, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildCasesChart() {
    return AspectRatio(
      aspectRatio: 5.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8)],
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
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: [
              _buildBarGroup(
                  0, 'Assigned', _chartData!['assigned'][0], Colors.blue),
              _buildBarGroup(
                  1, 'Finished', _chartData!['finished'][0], Colors.green),
              _buildBarGroup(
                  2, 'Cancel', _chartData!['cancelled'][0], Colors.red),
              _buildBarGroup(
                  3, 'Pending', _chartData!['pending'][0], Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionChart() {
    return AspectRatio(
      aspectRatio: 5.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8)],
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
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: [
              _buildBarGroup(0, 'Collect',
                  _collectionChartData!['collection'][0], Colors.indigo),
              _buildBarGroup(1, 'Recvd', _collectionChartData!['received'][0],
                  Colors.teal),
              _buildBarGroup(2, 'Credit', _collectionChartData!['credit'][0],
                  Colors.purple),
              _buildBarGroup(
                  3, 'B2B', _collectionChartData!['b2b'][0], Colors.brown),
              _buildBarGroup(
                  4, 'Trial', _collectionChartData!['trial'][0], Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(
      int x, String label, int value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.6)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter),
          width: 18,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _calculateMaxY(_chartData!),
              color: color.withOpacity(0.05)),
        ),
      ],
    );
  }

  BarTouchData _buildBarTouchData({bool isMoney = false}) {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.blueGrey.shade800,
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tooltipRoundedRadius: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final labels = isMoney
                ? ['Collect', 'Recvd', 'Credit', 'B2B', 'Trial']
                : ['Assigned', 'Finished', 'Cancel', 'Pending'];
            final val = rod.toY.toInt();
            return BarTooltipItem(
                '${labels[group.x]}\n',
                const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
                children: [
                  TextSpan(
                      text: isMoney
                          ? Util.formatMoney(val.toDouble())
                          : val.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ]);
          }),
    );
  }

  FlTitlesData _buildTitlesData(Map<String, dynamic> data, double interval,
      {bool isMoney = false}) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: isMoney ? 40 : 25,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            return Text(_formatCompactNumber(value.toInt()),
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 9,
                    fontWeight: FontWeight.bold));
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          getTitlesWidget: (value, meta) {
            final labels = isMoney
                ? ['Col', 'Rcv', 'Cr', 'B2B', 'Trl']
                : ['Asg', 'Fin', 'Can', 'Pen'];
            if (value.toInt() >= labels.length) return const Text('');
            return Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(labels[value.toInt()],
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)));
          },
        ),
      ),
    );
  }

  double _calculateMaxY(Map<String, dynamic> chartData) {
    final list = [
      ...chartData['assigned'],
      ...chartData['finished'],
      ...chartData['cancelled'],
      ...chartData['pending']
    ].cast<int>();
    if (list.isEmpty) return 10;
    final max = list.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }

  double _calculateMaxYCollection(Map<String, dynamic> chartData) {
    final list = [
      ...chartData['collection'],
      ...chartData['received'],
      ...chartData['credit'],
      ...chartData['b2b'],
      ...chartData['trial']
    ].cast<int>();
    if (list.isEmpty) return 1000;
    final max = list.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }

  double _calculateInterval(Map<String, dynamic> chartData) {
    double max = _calculateMaxY(chartData);
    if (max <= 10) return 2;
    return (max / 5).ceilToDouble();
  }

  double _calculateIntervalCollection(Map<String, dynamic> chartData) {
    double max = _calculateMaxYCollection(chartData);
    if (max <= 1000) return 200;
    return (max / 5).ceilToDouble();
  }

  String _formatCompactNumber(int value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

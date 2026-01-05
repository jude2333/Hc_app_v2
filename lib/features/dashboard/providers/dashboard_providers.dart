import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/services/dashboard_service.dart';
import '../models/dashboard_report.dart';
import 'dashboard_state.dart';

abstract class BaseDashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardService _service;
  bool _hasLoadedOnce = false;

  BaseDashboardNotifier(this._service) : super(const DashboardInitial());

  DashboardService get service => _service;

  Future<void> loadData();

  Future<void> loadWithState(
      Future<DashboardReport?> Function() fetcher) async {
    if (state is DashboardLoading) return;

    state = DashboardLoading(isFirstLoad: !_hasLoadedOnce);

    try {
      final report = await fetcher();

      if (report != null && report.hasData) {
        _hasLoadedOnce = true;
        state = DashboardLoaded(report);
      } else {
        _hasLoadedOnce = true;
        state = const DashboardError('No data available');
      }
    } catch (e) {
      _hasLoadedOnce = true;
      state = DashboardError(e.toString());
    }
  }

  Future<void> refresh() async {
    _hasLoadedOnce = true;
    await loadData();
  }
}

class DailyReportNotifier extends BaseDashboardNotifier {
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));

  DailyReportNotifier(super.service);

  DateTime get selectedDate => _selectedDate;

  @override
  Future<void> loadData() async {
    await loadWithState(() async {
      final year = _selectedDate.year.toString();
      final docId = 'daily_$year';
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final doc = await service.getOne(docId);
      if (doc == null || doc['data'] == null) return null;

      final data = doc['data'] as Map<String, dynamic>;
      final dayData = data[formattedDate];
      if (dayData == null) return null;

      final metrics = DashboardMetrics.fromMap(dayData);
      final label = DateFormat('MMM dd').format(_selectedDate);

      return DashboardReport(
        rows: [ReportRow(label: label, metrics: metrics)],
        totals: metrics,
        chartData: ChartData(
          labels: [label],
          assigned: [metrics.assigned],
          finished: [metrics.finished],
          cancelled: [metrics.cancelled],
          pending: [metrics.pending],
        ),
        financialChartData: FinancialChartData(
          labels: [label],
          collection: [metrics.collection.toInt()],
          received: [metrics.received.toInt()],
          credit: [metrics.credit.toInt()],
          b2b: [metrics.b2b.toInt()],
          trial: [metrics.trial.toInt()],
        ),
      );
    });
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    loadData();
  }
}

class WeeklyReportNotifier extends BaseDashboardNotifier {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now().subtract(const Duration(days: 1));

  WeeklyReportNotifier(super.service);

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  @override
  Future<void> loadData() async {
    await loadWithState(() async {
      final year = _startDate.year.toString();
      final docId = 'daily_$year';

      final doc = await service.getOne(docId);
      if (doc == null || doc['data'] == null) return null;

      final data = doc['data'] as Map<String, dynamic>;

      final rows = <ReportRow>[];
      final labels = <String>[];
      final assigned = <int>[];
      final finished = <int>[];
      final cancelled = <int>[];
      final pending = <int>[];
      final collection = <int>[];
      final received = <int>[];
      final credit = <int>[];
      final b2b = <int>[];
      final trial = <int>[];
      var totals = const DashboardMetrics();

      for (int i = 0; i < 7; i++) {
        final currentDate = _startDate.add(Duration(days: i));
        final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
        final dayData = data[formattedDate];
        final metrics = DashboardMetrics.fromMap(dayData);

        rows.add(ReportRow(
          label: DateFormat('MMM dd (E)').format(currentDate),
          metrics: metrics,
        ));

        labels.add(DateFormat('EEE').format(currentDate));
        assigned.add(metrics.assigned);
        finished.add(metrics.finished);
        cancelled.add(metrics.cancelled);
        pending.add(metrics.pending);
        collection.add(metrics.collection.toInt());
        received.add(metrics.received.toInt());
        credit.add(metrics.credit.toInt());
        b2b.add(metrics.b2b.toInt());
        trial.add(metrics.trial.toInt());
        totals = totals + metrics;
      }

      rows.add(ReportRow(label: 'Total', metrics: totals, isTotal: true));

      return DashboardReport(
        rows: rows,
        totals: totals,
        chartData: ChartData(
          labels: labels,
          assigned: assigned,
          finished: finished,
          cancelled: cancelled,
          pending: pending,
        ),
        financialChartData: FinancialChartData(
          labels: labels,
          collection: collection,
          received: received,
          credit: credit,
          b2b: b2b,
          trial: trial,
        ),
      );
    });
  }

  void selectDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    loadData();
  }
}

class MonthlyReportNotifier extends BaseDashboardNotifier {
  DateTime _selectedMonth = DateTime.now().subtract(const Duration(days: 30));

  MonthlyReportNotifier(super.service);

  DateTime get selectedMonth => _selectedMonth;

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  @override
  Future<void> loadData() async {
    await loadWithState(() async {
      final year = _selectedMonth.year.toString();
      final docId = 'weekly_$year';

      final doc = await service.getOne(docId);
      if (doc == null || doc['data'] == null) return null;

      final data = doc['data'] as Map<String, dynamic>;

      final rows = <ReportRow>[];
      final labels = <String>[];
      final assigned = <int>[];
      final finished = <int>[];
      final cancelled = <int>[];
      final pending = <int>[];
      final collection = <int>[];
      final received = <int>[];
      final credit = <int>[];
      final b2b = <int>[];
      final trial = <int>[];
      var totals = const DashboardMetrics();

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
        final metrics = DashboardMetrics.fromMap(weekData);

        rows.add(ReportRow(label: 'Week-$weekNum', metrics: metrics));
        labels.add('W$weekNum');
        assigned.add(metrics.assigned);
        finished.add(metrics.finished);
        cancelled.add(metrics.cancelled);
        pending.add(metrics.pending);
        collection.add(metrics.collection.toInt());
        received.add(metrics.received.toInt());
        credit.add(metrics.credit.toInt());
        b2b.add(metrics.b2b.toInt());
        trial.add(metrics.trial.toInt());
        totals = totals + metrics;
      }

      rows.add(ReportRow(label: 'Total', metrics: totals, isTotal: true));

      return DashboardReport(
        rows: rows,
        totals: totals,
        chartData: ChartData(
          labels: labels,
          assigned: assigned,
          finished: finished,
          cancelled: cancelled,
          pending: pending,
        ),
        financialChartData: FinancialChartData(
          labels: labels,
          collection: collection,
          received: received,
          credit: credit,
          b2b: b2b,
          trial: trial,
        ),
      );
    });
  }

  void selectMonth(DateTime date) {
    _selectedMonth = date;
    loadData();
  }
}

class YearlyReportNotifier extends BaseDashboardNotifier {
  int _selectedYear = DateTime.now().year;
  bool _monthwise = true;
  List<int> _availableYears = [];

  YearlyReportNotifier(super.service);

  int get selectedYear => _selectedYear;
  bool get monthwise => _monthwise;
  List<int> get availableYears => _availableYears;

  @override
  Future<void> loadData() async {
    await loadWithState(() async {
      if (_monthwise) {
        return _loadMonthlyData();
      } else {
        return _loadYearlyData();
      }
    });
  }

  Future<DashboardReport?> _loadMonthlyData() async {
    final docId = 'yearly_$_selectedYear';
    final doc = await service.getOne(docId);
    if (doc == null || doc['data'] == null) return null;

    final data = doc['data'] as Map<String, dynamic>;
    final rows = <ReportRow>[];
    final labels = <String>[];
    final assigned = <int>[];
    final finished = <int>[];
    final cancelled = <int>[];
    final pending = <int>[];
    final collection = <int>[];
    final received = <int>[];
    final credit = <int>[];
    final b2b = <int>[];
    final trial = <int>[];
    var totals = const DashboardMetrics();

    for (int month = 1; month <= 12; month++) {
      final monthData = data[month.toString()];
      final metrics = DashboardMetrics.fromMap(monthData);
      final monthName =
          DateFormat('MMMM').format(DateTime(_selectedYear, month, 1));

      rows.add(ReportRow(label: monthName, metrics: metrics));
      labels.add(DateFormat('MMM').format(DateTime(_selectedYear, month, 1)));
      assigned.add(metrics.assigned);
      finished.add(metrics.finished);
      cancelled.add(metrics.cancelled);
      pending.add(metrics.pending);
      collection.add(metrics.collection.toInt());
      received.add(metrics.received.toInt());
      credit.add(metrics.credit.toInt());
      b2b.add(metrics.b2b.toInt());
      trial.add(metrics.trial.toInt());
      totals = totals + metrics;
    }

    rows.add(ReportRow(label: 'Total', metrics: totals, isTotal: true));

    return DashboardReport(
      rows: rows,
      totals: totals,
      chartData: ChartData(
          labels: labels,
          assigned: assigned,
          finished: finished,
          cancelled: cancelled,
          pending: pending),
      financialChartData: FinancialChartData(
          labels: labels,
          collection: collection,
          received: received,
          credit: credit,
          b2b: b2b,
          trial: trial),
    );
  }

  Future<DashboardReport?> _loadYearlyData() async {
    final doc = await service.getOne('yearly');
    if (doc == null || doc['data'] == null) return null;

    final data = doc['data'] as Map<String, dynamic>;
    final rows = <ReportRow>[];
    final labels = <String>[];
    final assigned = <int>[];
    final finished = <int>[];
    final cancelled = <int>[];
    final pending = <int>[];
    final collection = <int>[];
    final received = <int>[];
    final credit = <int>[];
    final b2b = <int>[];
    final trial = <int>[];
    var totals = const DashboardMetrics();

    _availableYears = data.keys
        .map((k) => int.tryParse(k) ?? 0)
        .where((y) => y > 0)
        .toList()
      ..sort();

    final sortedKeys = data.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    for (final yearKey in sortedKeys) {
      final yearData = data[yearKey];
      final metrics = DashboardMetrics.fromMap(yearData);

      rows.add(ReportRow(label: yearKey, metrics: metrics));
      labels.add(yearKey);
      assigned.add(metrics.assigned);
      finished.add(metrics.finished);
      cancelled.add(metrics.cancelled);
      pending.add(metrics.pending);
      collection.add(metrics.collection.toInt());
      received.add(metrics.received.toInt());
      credit.add(metrics.credit.toInt());
      b2b.add(metrics.b2b.toInt());
      trial.add(metrics.trial.toInt());
      totals = totals + metrics;
    }

    rows.add(ReportRow(label: 'Total', metrics: totals, isTotal: true));

    return DashboardReport(
      rows: rows,
      totals: totals,
      chartData: ChartData(
          labels: labels,
          assigned: assigned,
          finished: finished,
          cancelled: cancelled,
          pending: pending),
      financialChartData: FinancialChartData(
          labels: labels,
          collection: collection,
          received: received,
          credit: credit,
          b2b: b2b,
          trial: trial),
    );
  }

  Future<void> loadAvailableYears() async {
    final doc = await service.getOne('yearly');
    if (doc != null && doc['data'] != null) {
      final data = doc['data'] as Map<String, dynamic>;
      _availableYears = data.keys
          .map((k) => int.tryParse(k) ?? 0)
          .where((y) => y > 0)
          .toList()
        ..sort();
      if (_availableYears.isNotEmpty) {
        _selectedYear = _availableYears.last;
      }
    }
    await loadData();
  }

  void selectYear(int year) {
    _selectedYear = year;
    loadData();
  }

  void toggleMonthwise(bool value) {
    _monthwise = value;
    loadData();
  }
}

final dailyReportProvider =
    StateNotifierProvider<DailyReportNotifier, DashboardState>((ref) {
  final service = ref.read(dashboardServiceProvider);
  return DailyReportNotifier(service);
});

final weeklyReportProvider =
    StateNotifierProvider<WeeklyReportNotifier, DashboardState>((ref) {
  final service = ref.read(dashboardServiceProvider);
  return WeeklyReportNotifier(service);
});

final monthlyReportProvider =
    StateNotifierProvider<MonthlyReportNotifier, DashboardState>((ref) {
  final service = ref.read(dashboardServiceProvider);
  return MonthlyReportNotifier(service);
});

final yearlyReportProvider =
    StateNotifierProvider<YearlyReportNotifier, DashboardState>((ref) {
  final service = ref.read(dashboardServiceProvider);
  return YearlyReportNotifier(service);
});

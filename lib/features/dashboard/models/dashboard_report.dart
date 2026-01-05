import 'package:flutter/foundation.dart';

@immutable
class DashboardMetrics {
  final int assigned;
  final int finished;
  final int cancelled;
  final int pending;
  final double collection;
  final double received;
  final double credit;
  final double b2b;
  final double trial;

  const DashboardMetrics({
    this.assigned = 0,
    this.finished = 0,
    this.cancelled = 0,
    this.pending = 0,
    this.collection = 0.0,
    this.received = 0.0,
    this.credit = 0.0,
    this.b2b = 0.0,
    this.trial = 0.0,
  });

  factory DashboardMetrics.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const DashboardMetrics();

    return DashboardMetrics(
      assigned: (data['assigned'] as num?)?.toInt() ?? 0,
      finished: (data['finished'] as num?)?.toInt() ?? 0,
      cancelled: (data['cancelled'] as num?)?.toInt() ?? 0,
      pending: (data['pending'] as num?)?.toInt() ?? 0,
      collection: (data['collection'] as num?)?.toDouble() ?? 0.0,
      received: (data['received'] as num?)?.toDouble() ?? 0.0,
      credit: (data['credit'] as num?)?.toDouble() ?? 0.0,
      b2b: (data['b2b'] as num?)?.toDouble() ?? 0.0,
      trial: (data['trial'] as num?)?.toDouble() ?? 0.0,
    );
  }

  DashboardMetrics operator +(DashboardMetrics other) {
    return DashboardMetrics(
      assigned: assigned + other.assigned,
      finished: finished + other.finished,
      cancelled: cancelled + other.cancelled,
      pending: pending + other.pending,
      collection: collection + other.collection,
      received: received + other.received,
      credit: credit + other.credit,
      b2b: b2b + other.b2b,
      trial: trial + other.trial,
    );
  }

  bool get isEmpty =>
      assigned == 0 &&
      finished == 0 &&
      cancelled == 0 &&
      pending == 0 &&
      collection == 0 &&
      received == 0;
}

@immutable
class ReportRow {
  final String label;
  final DashboardMetrics metrics;
  final bool isTotal;

  const ReportRow({
    required this.label,
    required this.metrics,
    this.isTotal = false,
  });
}

@immutable
class ChartData {
  final List<String> labels;
  final List<int> assigned;
  final List<int> finished;
  final List<int> cancelled;
  final List<int> pending;

  const ChartData({
    this.labels = const [],
    this.assigned = const [],
    this.finished = const [],
    this.cancelled = const [],
    this.pending = const [],
  });

  bool get isEmpty => labels.isEmpty;
}

@immutable
class FinancialChartData {
  final List<String> labels;
  final List<int> collection;
  final List<int> received;
  final List<int> credit;
  final List<int> b2b;
  final List<int> trial;

  const FinancialChartData({
    this.labels = const [],
    this.collection = const [],
    this.received = const [],
    this.credit = const [],
    this.b2b = const [],
    this.trial = const [],
  });

  bool get isEmpty => labels.isEmpty;
}

@immutable
class DashboardReport {
  final List<ReportRow> rows;
  final ChartData chartData;
  final FinancialChartData financialChartData;
  final DashboardMetrics totals;

  const DashboardReport({
    this.rows = const [],
    this.chartData = const ChartData(),
    this.financialChartData = const FinancialChartData(),
    this.totals = const DashboardMetrics(),
  });

  bool get isEmpty => rows.isEmpty;
  bool get hasData => rows.isNotEmpty;
}

enum ReportType {
  daily,
  weekly,
  monthly,
  yearly;

  String get title {
    switch (this) {
      case ReportType.daily:
        return 'Daily';
      case ReportType.weekly:
        return 'Weekly';
      case ReportType.monthly:
        return 'Monthly';
      case ReportType.yearly:
        return 'Yearly';
    }
  }

  String get periodLabel {
    switch (this) {
      case ReportType.daily:
        return 'Date';
      case ReportType.weekly:
        return 'Day';
      case ReportType.monthly:
        return 'Week';
      case ReportType.yearly:
        return 'Month';
    }
  }
}

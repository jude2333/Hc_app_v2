import 'package:flutter/foundation.dart';

/// Technician-specific analytics metrics.
/// Separate from [DashboardMetrics] to avoid polluting the manager model.
/// Computed from local PowerSync SQLite queries against hc_patient_visit_detail.
@immutable
class TechnicianMetrics {
  final int assigned;
  final int finished;
  final int cancelled;
  final int pending;
  final double totalReceived;
  final double cashCollected;
  final double gpayCollected;
  final double hcCharges;
  final double remittancePending;

  const TechnicianMetrics({
    this.assigned = 0,
    this.finished = 0,
    this.cancelled = 0,
    this.pending = 0,
    this.totalReceived = 0.0,
    this.cashCollected = 0.0,
    this.gpayCollected = 0.0,
    this.hcCharges = 0.0,
    this.remittancePending = 0.0,
  });

  double get completionRate =>
      assigned > 0 ? (finished / assigned) * 100 : 0.0;

  bool get isEmpty =>
      assigned == 0 &&
      finished == 0 &&
      cancelled == 0 &&
      pending == 0 &&
      totalReceived == 0;

  TechnicianMetrics operator +(TechnicianMetrics other) {
    return TechnicianMetrics(
      assigned: assigned + other.assigned,
      finished: finished + other.finished,
      cancelled: cancelled + other.cancelled,
      pending: pending + other.pending,
      totalReceived: totalReceived + other.totalReceived,
      cashCollected: cashCollected + other.cashCollected,
      gpayCollected: gpayCollected + other.gpayCollected,
      hcCharges: hcCharges + other.hcCharges,
      remittancePending: remittancePending + other.remittancePending,
    );
  }

  factory TechnicianMetrics.fromRow(Map<String, dynamic> row) {
    return TechnicianMetrics(
      assigned: _toInt(row['assigned']),
      finished: _toInt(row['finished']),
      cancelled: _toInt(row['cancelled']),
      pending: _toInt(row['pending']),
      totalReceived: _toDouble(row['total_received']),
      cashCollected: _toDouble(row['cash']),
      gpayCollected: _toDouble(row['gpay']),
      hcCharges: _toDouble(row['hc_charges']),
      remittancePending: _toDouble(row['remittance_pending']),
    );
  }

  static int _toInt(dynamic v) => (v is num) ? v.toInt() : 0;
  static double _toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
}

/// A single row in the technician report (one day or a totals row).
@immutable
class TechReportRow {
  final String label;
  final TechnicianMetrics metrics;
  final bool isTotal;

  const TechReportRow({
    required this.label,
    required this.metrics,
    this.isTotal = false,
  });
}

/// Complete technician report for rendering charts + tables.
@immutable
class TechnicianReport {
  final List<TechReportRow> rows;
  final TechnicianMetrics totals;

  /// Chart data — parallel arrays keyed by day label.
  final List<String> chartLabels;
  final List<int> chartAssigned;
  final List<int> chartFinished;
  final List<int> chartCancelled;
  final List<int> chartPending;
  final List<int> chartCash;
  final List<int> chartGpay;

  const TechnicianReport({
    this.rows = const [],
    this.totals = const TechnicianMetrics(),
    this.chartLabels = const [],
    this.chartAssigned = const [],
    this.chartFinished = const [],
    this.chartCancelled = const [],
    this.chartPending = const [],
    this.chartCash = const [],
    this.chartGpay = const [],
  });

  bool get hasData => rows.isNotEmpty && !totals.isEmpty;
}

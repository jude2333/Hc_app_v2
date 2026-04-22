import 'package:flutter/foundation.dart';

/// Range options for the analytics selector
enum AnalyticsRange { thisWeek, lastWeek, thisMonth, lastMonth, custom }

/// Per-test aggregation across a technician's orders
@immutable
class TestAggregation {
  final String investName;
  final String deptName;
  final int count;
  final double totalRevenue;

  const TestAggregation({
    required this.investName,
    this.deptName = '',
    this.count = 0,
    this.totalRevenue = 0,
  });

  TestAggregation addOccurrence(double cost) {
    return TestAggregation(
      investName: investName,
      deptName: deptName,
      count: count + 1,
      totalRevenue: totalRevenue + cost,
    );
  }
}

/// Per-technician analytics summary
@immutable
class TechAnalytics {
  final String techId;
  final String techName;

  // Order counts
  final int totalOrders;
  final int finished;
  final int cancelled;
  final int pending;

  // Financial
  final double totalBilled;
  final double totalReceived;
  final double totalDiscount;
  final double hcCharges;
  final double disposableCharges;
  final double cashCollected;
  final double gpayCollected;

  // Tests
  final int totalTests;
  final List<TestAggregation> testBreakdown;

  // B2B
  final Map<String, int> b2bBreakdown;

  // Raw orders for detail sheet export
  final List<Map<String, dynamic>> rawOrders;

  const TechAnalytics({
    required this.techId,
    required this.techName,
    this.totalOrders = 0,
    this.finished = 0,
    this.cancelled = 0,
    this.pending = 0,
    this.totalBilled = 0,
    this.totalReceived = 0,
    this.totalDiscount = 0,
    this.hcCharges = 0,
    this.disposableCharges = 0,
    this.cashCollected = 0,
    this.gpayCollected = 0,
    this.totalTests = 0,
    this.testBreakdown = const [],
    this.b2bBreakdown = const {},
    this.rawOrders = const [],
  });
}

/// Full analytics report
@immutable
class AnalyticsReport {
  final List<TechAnalytics> technicians;
  final TechAnalytics overallTotals;
  final DateTime startDate;
  final DateTime endDate;
  final String rangeLabel;

  const AnalyticsReport({
    required this.technicians,
    required this.overallTotals,
    required this.startDate,
    required this.endDate,
    required this.rangeLabel,
  });
}

/// State wrapper for the provider
@immutable
class TechAnalyticsState {
  final bool isLoading;
  final AnalyticsReport? report;
  final String? errorMessage;

  const TechAnalyticsState({
    this.isLoading = false,
    this.report,
    this.errorMessage,
  });

  TechAnalyticsState copyWith({
    bool? isLoading,
    AnalyticsReport? report,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TechAnalyticsState(
      isLoading: isLoading ?? this.isLoading,
      report: report ?? this.report,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

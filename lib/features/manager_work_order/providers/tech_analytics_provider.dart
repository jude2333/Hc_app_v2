import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import '../models/tech_analytics_models.dart';





final analyticsRangeProvider =
    StateProvider<AnalyticsRange>((ref) => AnalyticsRange.thisWeek);

final analyticsCustomStartProvider = StateProvider<DateTime?>((ref) => null);
final analyticsCustomEndProvider = StateProvider<DateTime?>((ref) => null);

final techAnalyticsProvider =
    StateNotifierProvider<TechAnalyticsNotifier, TechAnalyticsState>((ref) {
  return TechAnalyticsNotifier(ref);
});





class TechAnalyticsNotifier extends StateNotifier<TechAnalyticsState> {
  final Ref ref;

  TechAnalyticsNotifier(this.ref) : super(const TechAnalyticsState());

  
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final range = ref.read(analyticsRangeProvider);
      final dates = _getDateRange(range);
      final startDate = dates.$1;
      final endDate = dates.$2;
      final rangeLabel = dates.$3;

      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);

      final postgres = ref.read(postgresServiceProvider);

      
      final results = await Future.wait([
        postgres.getTechnicians(),
        postgres.getAllWorkOrdersForDateRange(startStr, endStr),
      ]);

      final techs = results[0] as List;
      final allOrders = results[1] as List<Map<String, dynamic>>;

      debugPrint(
          '[Analytics] Range: $startStr to $endStr | Techs: ${techs.length} | Orders: ${allOrders.length}');

      final report = _processData(
        techs,
        allOrders,
        startDate: startDate,
        endDate: endDate,
        rangeLabel: rangeLabel,
      );

      state = state.copyWith(isLoading: false, report: report);
    } catch (e) {
      debugPrint('[Analytics] loadData error: $e');
      state = state.copyWith(
          isLoading: false, errorMessage: 'Failed to load analytics: $e');
    }
  }

  
  (DateTime, DateTime, String) _getDateRange(AnalyticsRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (range) {
      case AnalyticsRange.thisWeek:
        
        final weekday = today.weekday; 
        final monday = today.subtract(Duration(days: weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return (monday, sunday, 'This Week');

      case AnalyticsRange.lastWeek:
        final weekday = today.weekday;
        final lastMonday =
            today.subtract(Duration(days: weekday - 1 + 7));
        final lastSunday = lastMonday.add(const Duration(days: 6));
        return (lastMonday, lastSunday, 'Last Week');

      case AnalyticsRange.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (
          start,
          end,
          DateFormat('MMMM yyyy').format(start),
        );

      case AnalyticsRange.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return (
          start,
          end,
          DateFormat('MMMM yyyy').format(start),
        );

      case AnalyticsRange.custom:
        final customStart = ref.read(analyticsCustomStartProvider);
        final customEnd = ref.read(analyticsCustomEndProvider);
        final s = customStart ?? today.subtract(const Duration(days: 7));
        final e = customEnd ?? today;
        return (
          s,
          e,
          '${DateFormat('dd MMM').format(s)} – ${DateFormat('dd MMM yyyy').format(e)}',
        );
    }
  }

  
  AnalyticsReport _processData(
    List<dynamic> rawTechs,
    List<Map<String, dynamic>> allOrders, {
    required DateTime startDate,
    required DateTime endDate,
    required String rangeLabel,
  }) {
    final technicians = rawTechs.isNotEmpty
        ? List<Map<String, dynamic>>.from(rawTechs)
        : <Map<String, dynamic>>[];

    final List<TechAnalytics> analytics = [];

    
    int gOrders = 0, gFinished = 0, gCancelled = 0, gPending = 0;
    double gBilled = 0,
        gReceived = 0,
        gDiscount = 0,
        gHc = 0,
        gDisposable = 0,
        gCash = 0,
        gGpay = 0;
    int gTests = 0;

    for (var tech in technicians) {
      final techId =
          tech['emp_id']?.toString() ?? tech['_id']?.toString() ?? '';
      final techName =
          tech['name'] ?? '${tech['first_name']} ${tech['last_name']}';

      int assigned = 0, finished = 0, cancelled = 0, pending = 0;
      double billed = 0,
          received = 0,
          discount = 0,
          hc = 0,
          disposable = 0,
          cash = 0,
          gpay = 0;
      int testCount = 0;

      final Map<String, TestAggregation> testMap = {};
      final Map<String, int> b2bMap = {};
      final List<Map<String, dynamic>> techOrders = [];

      for (var order in allOrders) {
        if (order['assigned_id']?.toString() != techId) continue;

        assigned++;
        techOrders.add(order);

        final status = order['status']?.toString() ?? '';
        if (status == 'Finished') {
          finished++;
        } else if (status == 'cancelled') {
          cancelled++;
        } else {
          pending++;
        }

        final doc = _parseDoc(order['doc']);

        
        final amountReceived =
            double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0;
        final hcCharge =
            double.tryParse(doc['hc_charges']?.toString() ?? '0') ?? 0;
        final disposableCharge =
            double.tryParse(doc['disposable_charges']?.toString() ?? '0') ?? 0;
        final discountVal =
            double.tryParse(doc['discount']?.toString() ?? '0') ?? 0;
        final paymentMethod = doc['payment_method']?.toString() ?? '';
        final billAmt =
            double.tryParse(order['bill_amount']?.toString() ?? '0') ??
                double.tryParse(doc['total']?.toString() ?? '0') ??
                0;

        billed += billAmt;
        received += amountReceived;
        discount += discountVal;
        hc += hcCharge;
        disposable += disposableCharge;

        if (amountReceived > 0) {
          if (paymentMethod == 'cash') cash += amountReceived;
          if (paymentMethod == 'gpay') gpay += amountReceived;
        }

        
        final testItems = doc['test_items'] as List? ?? [];
        for (final item in testItems) {
          testCount++;
          final investName =
              item['invest_name']?.toString() ?? 'Unknown Test';
          final deptName = item['dept_name']?.toString() ?? '';
          final baseCost =
              double.tryParse(item['base_cost']?.toString() ?? '0') ?? 0;

          if (testMap.containsKey(investName)) {
            testMap[investName] = testMap[investName]!.addOccurrence(baseCost);
          } else {
            testMap[investName] = TestAggregation(
              investName: investName,
              deptName: deptName,
              count: 1,
              totalRevenue: baseCost,
            );
          }
        }

        
        final b2bName = doc['b2b_client_name']?.toString() ??
            order['b2b_client_name']?.toString() ??
            '';
        if (b2bName.isNotEmpty && b2bName != '0') {
          b2bMap[b2bName] = (b2bMap[b2bName] ?? 0) + 1;
        }
      }

      
      gOrders += assigned;
      gFinished += finished;
      gCancelled += cancelled;
      gPending += pending;
      gBilled += billed;
      gReceived += received;
      gDiscount += discount;
      gHc += hc;
      gDisposable += disposable;
      gCash += cash;
      gGpay += gpay;
      gTests += testCount;

      
      if (assigned > 0 || technicians.length < 50) {
        
        final sortedTests = testMap.values.toList()
          ..sort((a, b) => b.count.compareTo(a.count));

        analytics.add(TechAnalytics(
          techId: techId,
          techName: techName,
          totalOrders: assigned,
          finished: finished,
          cancelled: cancelled,
          pending: pending,
          totalBilled: billed,
          totalReceived: received,
          totalDiscount: discount,
          hcCharges: hc,
          disposableCharges: disposable,
          cashCollected: cash,
          gpayCollected: gpay,
          totalTests: testCount,
          testBreakdown: sortedTests,
          b2bBreakdown: Map.unmodifiable(b2bMap),
          rawOrders: techOrders,
        ));
      }
    }

    
    analytics.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));

    final overall = TechAnalytics(
      techId: 'overall',
      techName: 'All Technicians',
      totalOrders: gOrders,
      finished: gFinished,
      cancelled: gCancelled,
      pending: gPending,
      totalBilled: gBilled,
      totalReceived: gReceived,
      totalDiscount: gDiscount,
      hcCharges: gHc,
      disposableCharges: gDisposable,
      cashCollected: gCash,
      gpayCollected: gGpay,
      totalTests: gTests,
    );

    return AnalyticsReport(
      technicians: analytics,
      overallTotals: overall,
      startDate: startDate,
      endDate: endDate,
      rangeLabel: rangeLabel,
    );
  }

  
  Map<String, dynamic> _parseDoc(dynamic doc) {
    try {
      if (doc == null) return {};
      if (doc is Map) return Map<String, dynamic>.from(doc);
      if (doc is String) {
        if (doc.isEmpty) return {};
        final decoded = jsonDecode(doc);
        if (decoded is String) return jsonDecode(decoded) as Map<String, dynamic>;
        return decoded as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[Analytics] Error parsing doc: $e');
    }
    return {};
  }
}

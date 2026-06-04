import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/features/session/storage_provider.dart';
import '../models/technician_metrics.dart';
import '../repositories/technician_analytics_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@immutable
sealed class TechDashboardState {
  const TechDashboardState();
}

final class TechDashboardInitial extends TechDashboardState {
  const TechDashboardInitial();
}

final class TechDashboardLoading extends TechDashboardState {
  final bool isFirstLoad;
  const TechDashboardLoading({this.isFirstLoad = true});
}

final class TechDashboardLoaded extends TechDashboardState {
  final TechnicianReport report;
  const TechDashboardLoaded(this.report);
}

final class TechDashboardError extends TechDashboardState {
  final String message;
  const TechDashboardError(this.message);
}

extension TechDashboardStateX on TechDashboardState {
  T when<T>({
    required T Function() initial,
    required T Function(bool isFirstLoad) loading,
    required T Function(TechnicianReport report) loaded,
    required T Function(String message) error,
  }) {
    return switch (this) {
      TechDashboardInitial() => initial(),
      TechDashboardLoading(:final isFirstLoad) => loading(isFirstLoad),
      TechDashboardLoaded(:final report) => loaded(report),
      TechDashboardError(:final message) => error(message),
    };
  }
}

// ---------------------------------------------------------------------------
// Daily Notifier
// ---------------------------------------------------------------------------

class TechDailyNotifier extends StateNotifier<TechDashboardState> {
  final TechnicianAnalyticsRepository _repo;
  final String _techId;
  DateTime _selectedDate = DateTime.now();
  StreamSubscription? _subscription;

  TechDailyNotifier(this._repo, this._techId)
      : super(const TechDashboardInitial());

  DateTime get selectedDate => _selectedDate;

  void selectDate(DateTime date) {
    _selectedDate = date;
    loadData();
  }

  Future<void> loadData() async {
    if (state is TechDashboardLoading) return;
    final isFirst = state is TechDashboardInitial;
    state = TechDashboardLoading(isFirstLoad: isFirst);

    // Cancel previous reactive stream
    await _subscription?.cancel();

    // Start reactive watch for real-time updates
    _subscription = _repo.watchDailyMetrics(_techId, _selectedDate).listen(
      (metrics) {
        final label = DateFormat('MMM dd').format(_selectedDate);
        final report = TechnicianReport(
          rows: [TechReportRow(label: label, metrics: metrics)],
          totals: metrics,
          chartLabels: [label],
          chartAssigned: [metrics.assigned],
          chartFinished: [metrics.finished],
          chartCancelled: [metrics.cancelled],
          chartPending: [metrics.pending],
          chartCash: [metrics.cashCollected.toInt()],
          chartGpay: [metrics.gpayCollected.toInt()],
        );
        state = TechDashboardLoaded(report);
      },
      onError: (e) {
        debugPrint('[TechDaily] Stream error: $e');
        if (state is! TechDashboardLoaded) {
          state = TechDashboardError(e.toString());
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Weekly Notifier
// ---------------------------------------------------------------------------

class TechWeeklyNotifier extends StateNotifier<TechDashboardState> {
  final TechnicianAnalyticsRepository _repo;
  final String _techId;
  bool _hasLoadedOnce = false;

  TechWeeklyNotifier(this._repo, this._techId)
      : super(const TechDashboardInitial());

  Future<void> loadData() async {
    if (state is TechDashboardLoading) return;
    state = TechDashboardLoading(isFirstLoad: !_hasLoadedOnce);

    try {
      final today = DateTime.now();
      final start = today.subtract(const Duration(days: 6));

      final metricsMap = await _repo.getRangeMetrics(_techId, start, today);

      final rows = <TechReportRow>[];
      final labels = <String>[];
      final assigned = <int>[];
      final finished = <int>[];
      final cancelled = <int>[];
      final pending = <int>[];
      final cash = <int>[];
      final gpay = <int>[];
      var totals = const TechnicianMetrics();

      // Iterate all 7 days to fill gaps with zeros
      for (int i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final dayLabel = DateFormat('EEE').format(day);
        final metrics = metricsMap[dateStr] ?? const TechnicianMetrics();

        rows.add(TechReportRow(
          label: DateFormat('MMM dd (E)').format(day),
          metrics: metrics,
        ));

        labels.add(dayLabel);
        assigned.add(metrics.assigned);
        finished.add(metrics.finished);
        cancelled.add(metrics.cancelled);
        pending.add(metrics.pending);
        cash.add(metrics.cashCollected.toInt());
        gpay.add(metrics.gpayCollected.toInt());
        totals = totals + metrics;
      }

      rows.add(TechReportRow(label: 'Total', metrics: totals, isTotal: true));

      _hasLoadedOnce = true;
      state = TechDashboardLoaded(TechnicianReport(
        rows: rows,
        totals: totals,
        chartLabels: labels,
        chartAssigned: assigned,
        chartFinished: finished,
        chartCancelled: cancelled,
        chartPending: pending,
        chartCash: cash,
        chartGpay: gpay,
      ));
    } catch (e) {
      _hasLoadedOnce = true;
      debugPrint('[TechWeekly] loadData error: $e');
      state = TechDashboardError(e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final techDailyProvider =
    StateNotifierProvider<TechDailyNotifier, TechDashboardState>((ref) {
  final repo = ref.watch(techAnalyticsRepositoryProvider);
  final storage = ref.read(storageServiceProvider);
  final techId = storage.getFromSession('logged_in_emp_id');
  return TechDailyNotifier(repo, techId);
});

final techWeeklyProvider =
    StateNotifierProvider<TechWeeklyNotifier, TechDashboardState>((ref) {
  final repo = ref.watch(techAnalyticsRepositoryProvider);
  final storage = ref.read(storageServiceProvider);
  final techId = storage.getFromSession('logged_in_emp_id');
  return TechWeeklyNotifier(repo, techId);
});

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import '../models/technician_metrics.dart';

/// Repository for computing technician analytics from local PowerSync SQLite.
/// All queries run against the synced hc_patient_visit_detail table.
/// Financial details are extracted from the doc JSON column via json_extract().
class TechnicianAnalyticsRepository {
  final PowerSyncService _ps;

  TechnicianAnalyticsRepository(this._ps);

  static const _baseCols = '''
    COUNT(*) as assigned,
    SUM(CASE WHEN status = 'Finished' THEN 1 ELSE 0 END) as finished,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled,
    SUM(CASE WHEN status NOT IN ('Finished', 'cancelled') THEN 1 ELSE 0 END) as pending,
    COALESCE(SUM(received_amount), 0) as total_received,
    COALESCE(SUM(CASE WHEN json_extract(doc, '\$.payment_method') = 'cash'
      THEN received_amount ELSE 0 END), 0) as cash,
    COALESCE(SUM(CASE WHEN json_extract(doc, '\$.payment_method') = 'gpay'
      THEN received_amount ELSE 0 END), 0) as gpay,
    COALESCE(SUM(CAST(COALESCE(json_extract(doc, '\$.hc_charges'), '0') AS REAL)), 0) as hc_charges,
    COALESCE(SUM(
      CASE WHEN json_extract(doc, '\$.amount_deposit') IS NOT NULL
        AND (json_extract(doc, '\$.accept_remittance') = 0
             OR json_extract(doc, '\$.accept_remittance') = 'false'
             OR json_extract(doc, '\$.amount_deposited_status') = 0
             OR json_extract(doc, '\$.amount_deposited_status') = 'false')
      THEN CAST(COALESCE(json_extract(doc, '\$.amount_deposit'), '0') AS REAL)
      ELSE 0 END
    ), 0) as remittance_pending
  ''';

  /// Fetch metrics for a single date.
  Future<TechnicianMetrics> getDailyMetrics(
      String techId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final rows = await _ps.db.getAll(
        '''
        SELECT $_baseCols
        FROM hc_patient_visit_detail
        WHERE assigned_id = ? AND visit_date = ? AND visible = 1
        ''',
        [techId, dateStr],
      );
      if (rows.isEmpty) return const TechnicianMetrics();
      return TechnicianMetrics.fromRow(rows.first);
    } catch (e) {
      debugPrint('[TechAnalytics] getDailyMetrics error: $e');
      return const TechnicianMetrics();
    }
  }

  /// Fetch metrics grouped by date for a date range.
  /// Returns a map of date string → metrics.
  Future<Map<String, TechnicianMetrics>> getRangeMetrics(
      String techId, DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    try {
      final rows = await _ps.db.getAll(
        '''
        SELECT visit_date, $_baseCols
        FROM hc_patient_visit_detail
        WHERE assigned_id = ? AND visit_date >= ? AND visit_date <= ? AND visible = 1
        GROUP BY visit_date
        ORDER BY visit_date ASC
        ''',
        [techId, startStr, endStr],
      );

      final result = <String, TechnicianMetrics>{};
      for (final row in rows) {
        final dateKey = row['visit_date']?.toString() ?? '';
        if (dateKey.isNotEmpty) {
          result[dateKey] = TechnicianMetrics.fromRow(row);
        }
      }
      return result;
    } catch (e) {
      debugPrint('[TechAnalytics] getRangeMetrics error: $e');
      return {};
    }
  }

  /// Reactive stream for daily metrics — rebuilds when any work order changes.
  Stream<TechnicianMetrics> watchDailyMetrics(
      String techId, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _ps
        .createRecoverableWatch(
          '''
          SELECT $_baseCols
          FROM hc_patient_visit_detail
          WHERE assigned_id = ? AND visit_date = ? AND visible = 1
          ''',
          [techId, dateStr],
        )
        .map((rows) =>
            rows.isEmpty ? const TechnicianMetrics() : TechnicianMetrics.fromRow(rows.first));
  }
}

final techAnalyticsRepositoryProvider =
    Provider<TechnicianAnalyticsRepository>((ref) {
  final ps = ref.watch(powerSyncServiceProvider);
  return TechnicianAnalyticsRepository(ps);
});

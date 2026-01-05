import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/dashboardDb.dart';

class DashboardService {
  final Ref ref;
  DashboardService(this.ref);

  Future<Map<String, dynamic>?> getOne(String docId) async =>
      ref.read(dashboardDbProvider).getOne(docId);

  Future<List<Map<String, dynamic>>> getMultiple(List<String> ids) async =>
      ref.read(dashboardDbProvider).getMultiple(ids);

  Future<List<Map<String, dynamic>>> getAll() async =>
      ref.read(dashboardDbProvider).getAll();

  Future<List<Map<String, dynamic>>> query(
          {bool Function(Map<String, dynamic>)? filter}) async =>
      ref.read(dashboardDbProvider).query(filter: filter);

  Future<bool> exists(String docId) async =>
      ref.read(dashboardDbProvider).exists(docId);

  Future<String> put(String docId, Map<String, dynamic> doc) async =>
      ref.read(dashboardDbProvider).put(docId, doc);

  Future<String> delete(String docId) async =>
      ref.read(dashboardDbProvider).delete(docId);
}

/* ----------  Riverpod provider  ---------- */
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref);
});

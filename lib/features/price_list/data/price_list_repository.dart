import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'price_list_model.dart';

class PriceListRepository {
  final PowerSyncDatabase _db;

  PriceListRepository(this._db);

  Future<List<PriceListItem>> fetchAll({String query = ''}) async {
    debugPrint('📊 [PriceListRepo] fetchAll(query: "$query")');

    String sql;
    List<dynamic> params = [];

    if (query.isEmpty) {
      sql = '''
        SELECT * FROM price_list 
        WHERE visible = 1 
        ORDER BY invest_name ASC
      ''';
    } else if (query.contains('>') ||
        query.contains('<') ||
        query.contains('=')) {
      final numericValue = _extractNumber(query);
      if (query.contains('>')) {
        sql = '''
          SELECT * FROM price_list 
          WHERE visible = 1 AND base_cost > ? 
          ORDER BY base_cost DESC
        ''';
      } else if (query.contains('<')) {
        sql = '''
          SELECT * FROM price_list 
          WHERE visible = 1 AND base_cost < ? 
          ORDER BY base_cost ASC
        ''';
      } else {
        sql = '''
          SELECT * FROM price_list 
          WHERE visible = 1 AND base_cost = ? 
          ORDER BY invest_name ASC
        ''';
      }
      params = [numericValue];
    } else if (query.toLowerCase().startsWith('id:')) {
      final idValue = query.substring(3).trim();
      sql = '''
        SELECT * FROM price_list 
        WHERE visible = 1 AND invest_id = ? 
        ORDER BY invest_name ASC
      ''';
      params = [idValue];
    } else {
      sql = '''
        SELECT * FROM price_list 
        WHERE visible = 1 
          AND (invest_name LIKE ? OR dept_name LIKE ?)
        ORDER BY invest_name ASC
      ''';
      final searchTerm = '%$query%';
      params = [searchTerm, searchTerm];
    }

    try {
      final results = await _db.getAll(sql, params);
      final items = results.map((row) => PriceListItem.fromRow(row)).toList();
      debugPrint('✅ [PriceListRepo] Found ${items.length} items');
      return items;
    } catch (e) {
      debugPrint('❌ [PriceListRepo] fetchAll error: $e');
      return [];
    }
  }

  Future<PriceListItem?> getById(String id) async {
    debugPrint('📊 [PriceListRepo] getById($id)');

    try {
      final results = await _db.getAll(
        'SELECT * FROM price_list WHERE id = ?',
        [id],
      );

      if (results.isEmpty) {
        debugPrint('⚠️ [PriceListRepo] Item not found: $id');
        return null;
      }

      return PriceListItem.fromRow(results.first);
    } catch (e) {
      debugPrint('❌ [PriceListRepo] getById error: $e');
      return null;
    }
  }

  Stream<List<PriceListItem>> watchAll({String query = ''}) {
    debugPrint('👁️ [PriceListRepo] watchAll(query: "$query")');

    String sql;
    List<dynamic> params = [];

    if (query.isEmpty) {
      sql =
          'SELECT * FROM price_list WHERE visible = 1 ORDER BY invest_name ASC';
    } else {
      sql = '''
        SELECT * FROM price_list 
        WHERE visible = 1 
          AND (invest_name LIKE ? OR dept_name LIKE ?)
        ORDER BY invest_name ASC
      ''';
      final searchTerm = '%$query%';
      params = [searchTerm, searchTerm];
    }

    return _db.watch(sql, parameters: params).map((results) {
      return results.map((row) => PriceListItem.fromRow(row)).toList();
    });
  }

  Future<String> insert(PriceListItem item) async {
    debugPrint('📤 [PriceListRepo] insert(${item.investName})');

    try {
      final row = item.toRow();

      await _db.execute('''
        INSERT INTO price_list (
          id, dept_id, dept_name, invest_id, invest_name, rate_card_name,
          base_cost, min_cost, cghs_price, history,
          created_at, updated_at, last_updated_by, visible
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        row['id'],
        row['dept_id'],
        row['dept_name'],
        row['invest_id'],
        row['invest_name'],
        row['rate_card_name'],
        row['base_cost'],
        row['min_cost'],
        row['cghs_price'],
        row['history'],
        row['created_at'],
        row['updated_at'],
        row['last_updated_by'],
        row['visible'],
      ]);

      debugPrint('✅ [PriceListRepo] Inserted: ${item.id}');
      return 'OK';
    } catch (e) {
      debugPrint('❌ [PriceListRepo] insert error: $e');
      return 'Error: $e';
    }
  }

  Future<String> update(PriceListItem item) async {
    debugPrint('🔄 [PriceListRepo] update(${item.id})');

    try {
      final row = item.toRow();

      await _db.execute('''
        UPDATE price_list SET
          dept_id = ?,
          dept_name = ?,
          invest_id = ?,
          invest_name = ?,
          rate_card_name = ?,
          base_cost = ?,
          min_cost = ?,
          cghs_price = ?,
          history = ?,
          updated_at = ?,
          last_updated_by = ?,
          visible = ?
        WHERE id = ?
      ''', [
        row['dept_id'],
        row['dept_name'],
        row['invest_id'],
        row['invest_name'],
        row['rate_card_name'],
        row['base_cost'],
        row['min_cost'],
        row['cghs_price'],
        row['history'],
        row['updated_at'],
        row['last_updated_by'],
        row['visible'],
        row['id'],
      ]);

      debugPrint('✅ [PriceListRepo] Updated: ${item.id}');
      return 'OK';
    } catch (e) {
      debugPrint('❌ [PriceListRepo] update error: $e');
      return 'Error: $e';
    }
  }

  Future<String> softDelete(String id) async {
    debugPrint('🗑️ [PriceListRepo] softDelete($id)');

    try {
      await _db.execute(
        'UPDATE price_list SET visible = 0, updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );

      debugPrint('✅ [PriceListRepo] Soft deleted: $id');
      return 'OK';
    } catch (e) {
      debugPrint('❌ [PriceListRepo] softDelete error: $e');
      return 'Error: $e';
    }
  }

  Future<String> hardDelete(String id) async {
    debugPrint('🗑️ [PriceListRepo] hardDelete($id)');

    try {
      await _db.execute('DELETE FROM price_list WHERE id = ?', [id]);

      debugPrint('✅ [PriceListRepo] Hard deleted: $id');
      return 'OK';
    } catch (e) {
      debugPrint('❌ [PriceListRepo] hardDelete error: $e');
      return 'Error: $e';
    }
  }

  Future<Map<String, String>> getDepartmentMap() async {
    debugPrint('📊 [PriceListRepo] getDepartmentMap()');

    try {
      final results = await _db.getAll('''
        SELECT DISTINCT dept_id, dept_name 
        FROM price_list 
        WHERE visible = 1 AND dept_id IS NOT NULL AND dept_name IS NOT NULL
        ORDER BY dept_name ASC
      ''');

      final Map<String, String> deptMap = {};
      for (final row in results) {
        final name = row['dept_name']?.toString().toLowerCase() ?? '';
        final id = row['dept_id']?.toString() ?? '';
        if (name.isNotEmpty && id.isNotEmpty) {
          deptMap[name] = id;
        }
      }

      debugPrint('✅ [PriceListRepo] Found ${deptMap.length} departments');
      return deptMap;
    } catch (e) {
      debugPrint('❌ [PriceListRepo] getDepartmentMap error: $e');
      return {};
    }
  }

  Future<Map<String, String>> getInvestigationMap() async {
    debugPrint('📊 [PriceListRepo] getInvestigationMap()');

    try {
      final results = await _db.getAll('''
        SELECT DISTINCT invest_id, invest_name 
        FROM price_list 
        WHERE visible = 1 AND invest_id IS NOT NULL AND invest_name IS NOT NULL
        ORDER BY invest_name ASC
      ''');

      final Map<String, String> investMap = {};
      for (final row in results) {
        final id = row['invest_id']?.toString() ?? '';
        final name = row['invest_name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          investMap[id] = name;
        }
      }

      debugPrint('✅ [PriceListRepo] Found ${investMap.length} investigations');
      return investMap;
    } catch (e) {
      debugPrint('❌ [PriceListRepo] getInvestigationMap error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalHistory({int limit = 100}) async {
    debugPrint('📜 [PriceListRepo] getGlobalHistory(limit: $limit)');

    try {
      final results = await _db.getAll('''
        SELECT id, invest_name, history 
        FROM price_list 
        WHERE history IS NOT NULL AND history != '[]'
        ORDER BY updated_at DESC
      ''');

      final List<Map<String, dynamic>> allHistory = [];

      for (final row in results) {
        try {
          final historyJson = row['history']?.toString() ?? '[]';
          final List<dynamic> itemHistory = jsonDecode(historyJson);

          for (final entry in itemHistory) {
            if (entry is Map<String, dynamic>) {
              allHistory.add({
                ...entry,
                'item_id': row['id'],
                'invest_name': row['invest_name'],
              });
            }
          }
        } catch (e) {}
      }

      allHistory.sort((a, b) {
        final aTime = a['time_stamp']?.toString() ?? '';
        final bTime = b['time_stamp']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });

      final limited = allHistory.take(limit).toList();
      debugPrint('✅ [PriceListRepo] Found ${limited.length} history entries');
      return limited;
    } catch (e) {
      debugPrint('❌ [PriceListRepo] getGlobalHistory error: $e');
      return [];
    }
  }

  double _extractNumber(String query) {
    final match = RegExp(r'[\d.]+').firstMatch(query);
    return match != null ? double.tryParse(match.group(0)!) ?? 0 : 0;
  }
}

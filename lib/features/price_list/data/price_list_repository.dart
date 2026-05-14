import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'price_list_model.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';

class PriceListRepository {
  final PowerSyncDatabase _db;
  final PowerSyncService _powerSync = PowerSyncService.instance;

  PriceListRepository(this._db);

  Future<List<PriceListItem>> fetchAll({String query = ''}) async {
    debugPrint(' [PriceListRepo] fetchAll(query: "$query")');

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
      debugPrint(' [PriceListRepo] Found ${items.length} items');
      return items;
    } catch (e) {
      debugPrint(' [PriceListRepo] fetchAll error: $e');
      return [];
    }
  }

  Future<PriceListItem?> getById(String id) async {
    debugPrint(' [PriceListRepo] getById($id)');

    try {
      final results = await _db.getAll(
        'SELECT * FROM price_list WHERE id = ?',
        [id],
      );

      if (results.isEmpty) {
        debugPrint(' [PriceListRepo] Item not found: $id');
        return null;
      }

      return PriceListItem.fromRow(results.first);
    } catch (e) {
      debugPrint(' [PriceListRepo] getById error: $e');
      return null;
    }
  }

  Stream<List<PriceListItem>> watchAll({String query = ''}) {
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

    return _powerSync.createRecoverableWatch(sql, params).map((results) {
      return results.map((row) => PriceListItem.fromRow(row)).toList();
    });
  }

  Future<String> insert(PriceListItem item) async {
    debugPrint(' [PriceListRepo] insert(${item.investName})');

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

      debugPrint(' [PriceListRepo] Inserted: ${item.id}');
      return 'OK';
    } catch (e) {
      debugPrint(' [PriceListRepo] insert error: $e');
      return 'Error: $e';
    }
  }

  Future<String> update(PriceListItem item) async {
    debugPrint(' [PriceListRepo] update(${item.id})');

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

      debugPrint(' [PriceListRepo] Updated: ${item.id}');
      return 'OK';
    } catch (e) {
      debugPrint(' [PriceListRepo] update error: $e');
      return 'Error: $e';
    }
  }

  Future<String> softDelete(String id) async {
    debugPrint(' [PriceListRepo] softDelete($id)');

    try {
      await _db.execute(
        'UPDATE price_list SET visible = 0, updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );

      debugPrint(' [PriceListRepo] Soft deleted: $id');
      return 'OK';
    } catch (e) {
      debugPrint(' [PriceListRepo] softDelete error: $e');
      return 'Error: $e';
    }
  }

  Future<String> hardDelete(String id) async {
    debugPrint(' [PriceListRepo] hardDelete($id)');

    try {
      await _db.execute('DELETE FROM price_list WHERE id = ?', [id]);

      debugPrint(' [PriceListRepo] Hard deleted: $id');
      return 'OK';
    } catch (e) {
      debugPrint(' [PriceListRepo] hardDelete error: $e');
      return 'Error: $e';
    }
  }

  Future<Map<String, String>> getDepartmentMap() async {
    debugPrint(' [PriceListRepo] getDepartmentMap()');

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

      debugPrint(' [PriceListRepo] Found ${deptMap.length} departments');
      return deptMap;
    } catch (e) {
      debugPrint(' [PriceListRepo] getDepartmentMap error: $e');
      return {};
    }
  }

  Future<Map<String, String>> getInvestigationMap() async {
    debugPrint(' [PriceListRepo] getInvestigationMap()');

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

      debugPrint(' [PriceListRepo] Found ${investMap.length} investigations');
      return investMap;
    } catch (e) {
      debugPrint(' [PriceListRepo] getInvestigationMap error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getGlobalHistory({int limit = 100}) async {
    debugPrint(' [PriceListRepo] getGlobalHistory(limit: $limit)');

    try {
      final results = await _db.getAll('''
        SELECT id, invest_name, history 
        FROM price_list 
        WHERE history IS NOT NULL 
          AND history != '[]' 
          AND history != '' 
          AND history != 'null'
          AND LENGTH(history) > 2
        ORDER BY updated_at DESC
      ''');

      debugPrint(
          ' [PriceListRepo] Query returned ${results.length} rows with history data');

      final List<Map<String, dynamic>> allHistory = [];

      for (final row in results) {
        try {
          final rawHistory = row['history'];
          debugPrint(
              ' [PriceListRepo] Row ${row['invest_name']}: history type=${rawHistory.runtimeType}, value=${rawHistory.toString().substring(0, rawHistory.toString().length > 100 ? 100 : rawHistory.toString().length)}...');

          List<dynamic> itemHistory;

          if (rawHistory is List) {
            // Already parsed as a List (PowerSync may deserialize JSONB)
            itemHistory = rawHistory;
          } else if (rawHistory is String) {
            itemHistory = jsonDecode(rawHistory);
          } else {
            debugPrint(
                ' [PriceListRepo] Unexpected history type: ${rawHistory.runtimeType}');
            continue;
          }

          debugPrint(
              ' [PriceListRepo] Parsed ${itemHistory.length} entries for ${row['invest_name']}');

          for (final entry in itemHistory) {
            if (entry is Map<String, dynamic>) {
              allHistory.add({
                ...entry,
                'item_id': row['id'],
                'invest_name': row['invest_name'],
              });
            } else if (entry is Map) {
              allHistory.add({
                ...Map<String, dynamic>.from(entry),
                'item_id': row['id'],
                'invest_name': row['invest_name'],
              });
            }
          }
        } catch (e) {
          debugPrint(
              ' [PriceListRepo] Error parsing history for ${row['id']}: $e');
        }
      }

      allHistory.sort((a, b) {
        final aTime = _parseHistoryTimestamp(a['time_stamp']?.toString() ?? '');
        final bTime = _parseHistoryTimestamp(b['time_stamp']?.toString() ?? '');
        return bTime.compareTo(aTime); // descending (newest first)
      });

      final limited = allHistory.take(limit).toList();
      debugPrint(' [PriceListRepo] Final history entries: ${limited.length}');
      return limited;
    } catch (e) {
      debugPrint(' [PriceListRepo] getGlobalHistory error: $e');
      return [];
    }
  }

  double _extractNumber(String query) {
    final match = RegExp(r'[\d.]+').firstMatch(query);
    return match != null ? double.tryParse(match.group(0)!) ?? 0 : 0;
  }

  /// Parses "DD-MM-YYYY h:mm:ss am/pm" into DateTime for sorting
  DateTime _parseHistoryTimestamp(String stamp) {
    try {
      // "03-05-2026 2:45:56 pm"
      final parts = stamp.split(' ');
      if (parts.length < 3) return DateTime(2000);

      final dateParts = parts[0].split('-');
      if (dateParts.length != 3) return DateTime(2000);

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final timeParts = parts[1].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

      final ampm = parts[2].toLowerCase();
      if (ampm == 'pm' && hour != 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      return DateTime(2000); // fallback for unparseable timestamps
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'db_handler.dart';
import 'couch_db.dart';
import '../repositories/storage_repository.dart';
import '../features/core/util.dart';
import 'cghs_data.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';

class PriceListDB {
  final DBHandler _dbHandler;
  final CouchDBClient _couchDB;
  final StorageService _storage;
  PriceListDB(this._dbHandler, this._couchDB, this._storage);

  Future<List<Map<String, dynamic>>> fetchDataRemote(String str) async {
    debugPrint('Remote Fetch data > fetchDataRemote() > $str');
    String? name = _dbHandler.resolveName('price_list');
    if (name == null) {
      debugPrint('Could not resolve price_list database name');
      return [];
    }

    Dio? remoteDb = await _couchDB.getDB(name);
    if (remoteDb == null) {
      debugPrint('Remote DB connection is null');
      return [];
    }

    List<Map<String, dynamic>> items = [];
    str = str.trim().toLowerCase();

    try {
      Response response = await remoteDb.get(
        '/_all_docs',
        queryParameters: {
          'include_docs': true,
          'startkey': jsonEncode('price_list:abp:'),
          'endkey': jsonEncode('price_list:abp:\ufff0'),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null) {
            Map<String, dynamic> item = Map<String, dynamic>.from(row['doc']);
            item = _addCghsPrice(item);

            if (str.isNotEmpty) {
              String searchItem =
                  (item['invest_name'] ?? '').toString().toLowerCase();
              if (searchItem.contains(str)) {
                items.add(item);
              }
            } else {
              items.add(item);
            }

            if (items.length > 29) {
              break;
            }
          }
        }
      }

      if (items.isEmpty) {
        items.add({
          'invest_name': 'No Investigation Found.',
          'department_name': 'NA',
          'base_cost': '0',
          'min_cost': '0',
        });
      }

      debugPrint('Found ${items.length} items from remote');
      return items;
    } catch (e) {
      debugPrint('Error fetching remote price list data: $e');
      return [
        {
          'invest_name': 'Error fetching data.',
          'department_name': 'NA',
          'base_cost': '0',
          'min_cost': '0',
        }
      ];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllDataRemote(String str) async {
    debugPrint('Remote Fetch all data > fetchAllDataRemote() > $str');
    String? name = _dbHandler.resolveName('price_list');
    if (name == null) {
      debugPrint('Could not resolve price_list database name');
      return [];
    }

    Dio? remoteDb = await _couchDB.getDB(name);
    if (remoteDb == null) {
      debugPrint('Remote DB connection is null');
      return [];
    }

    List<Map<String, dynamic>> items = [];
    str = str.trim().toLowerCase();

    try {
      Response response = await remoteDb.get(
        '/_all_docs',
        queryParameters: {
          'include_docs': true,
          'startkey': jsonEncode('price_list:abp:'),
          'endkey': jsonEncode('price_list:abp:\ufff0'),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null) {
            Map<String, dynamic> item = Map<String, dynamic>.from(row['doc']);
            item = _addCghsPrice(item);

            if (str.isNotEmpty) {
              if (str.contains('>') || str.contains('<') || str.contains('=')) {
                int itemCost =
                    int.tryParse(item['base_cost']?.toString() ?? '0') ?? 0;
                int entValue = Util.getNumbers(str);

                if (str.contains('>')) {
                  if (itemCost > entValue) items.add(item);
                } else if (str.contains('<')) {
                  if (itemCost < entValue) items.add(item);
                } else if (str.contains('=')) {
                  if (itemCost == entValue) items.add(item);
                }
              } else if (str.contains('id:')) {
                int investId =
                    int.tryParse(item['invest_id']?.toString() ?? '0') ?? 0;
                int entValue = Util.getNumbers(str);
                if (investId == entValue) items.add(item);
              } else if (!_isNumeric(str)) {
                String searchItem =
                    '${(item['invest_name'] ?? '').toString().toLowerCase()} *** ${(item['dept_name'] ?? '').toString().toLowerCase()}';
                if (searchItem.contains(str)) items.add(item);
              } else {
                if (str == item['base_cost']?.toString()) items.add(item);
              }
            } else {
              items.add(item);
            }
          }
        }
      }

      if (items.isEmpty) {
        items.add({
          'invest_name': 'No Investigation Found.',
          'department_name': 'NA',
          'base_cost': '0',
          'min_cost': '0',
          'cghs_price': '0',
        });
      }

      debugPrint('Found ${items.length} items from remote (all data)');
      return items;
    } catch (e) {
      debugPrint('Error fetching all remote price list data: $e');
      return [
        {
          'invest_name': 'Error fetching data.',
          'department_name': 'NA',
          'base_cost': '0',
          'min_cost': '0',
          'cghs_price': '0',
        }
      ];
    }
  }

  Future<String> insertNew(Map<String, dynamic> doc) async {
    try {
      debugPrint('📤 Inserting new price list item to remote...');

      String docId = doc['_id'] ?? '';
      if (docId.isEmpty) {
        return 'Error: Document ID is required';
      }

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        return 'Error: Could not resolve price_list database name';
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        return 'Error: Remote DB connection is null';
      }

      // Add metadata
      doc['updated_at'] = Util.getTimeStamp();

      Response response = await remoteDb.put('/$docId', data: doc);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Document inserted successfully: $docId');
        return 'OK';
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Document conflict (409), resolving...');
        return await _resolveConflictAndRetry(remoteDb, docId, doc);
      } else {
        debugPrint('❌ Failed to insert: ${response.statusCode}');
        return 'Error: ${response.statusMessage}';
      }
    } catch (err) {
      debugPrint('❌ Error inserting document: $err');
      return 'Error: $err';
    }
  }

  /// ✅ Converted to remote
  Future<String> deleteOne(String docId) async {
    try {
      debugPrint('🗑️ Deleting price list item from remote: $docId');

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        return 'Error: Could not resolve price_list database name';
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        return 'Error: Remote DB connection is null';
      }

      // Get current document to retrieve _rev
      Response getResponse = await remoteDb.get('/$docId');

      if (getResponse.statusCode != 200) {
        return 'Error: Document not found';
      }

      String rev = getResponse.data['_rev'];

      // Delete document
      Response deleteResponse = await remoteDb.delete(
        '/$docId',
        queryParameters: {'rev': rev},
      );

      if (deleteResponse.statusCode == 200 ||
          deleteResponse.statusCode == 204) {
        debugPrint('✅ Document deleted successfully: $docId');
        return 'OK';
      } else {
        debugPrint('❌ Failed to delete: ${deleteResponse.statusCode}');
        return 'Error: ${deleteResponse.statusMessage}';
      }
    } catch (err) {
      debugPrint('❌ Error deleting document: $err');
      return 'Error: $err';
    }
  }

  /// ✅ Converted to remote
  Future<Map<String, dynamic>?> getOne(String docId) async {
    try {
      debugPrint('📥 Getting price list item from remote: $docId');

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        debugPrint('Could not resolve price_list database name');
        return null;
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        debugPrint('Remote DB connection is null');
        return null;
      }

      Response response = await remoteDb.get('/$docId');

      if (response.statusCode == 200) {
        debugPrint('✅ Document retrieved successfully: $docId');
        return Map<String, dynamic>.from(response.data);
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Document not found: $docId');
        return null;
      } else {
        debugPrint('❌ Failed to get document: ${response.statusCode}');
        return null;
      }
    } catch (err) {
      debugPrint('❌ Error getting document: $err');
      return null;
    }
  }

  Future<String> update(Map<String, dynamic> newDoc) async {
    try {
      debugPrint('🔄 Updating price list item in remote...');

      String docId = newDoc['_id'] ?? '';
      if (docId.isEmpty) {
        return 'Error: Document ID is required';
      }

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        return 'Error: Could not resolve price_list database name';
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        return 'Error: Remote DB connection is null';
      }

      // Get current document to retrieve _rev
      Map<String, dynamic>? oldDoc = await getOne(docId);

      if (oldDoc != null) {
        newDoc['_rev'] = oldDoc['_rev'];
      }

      // Update metadata
      newDoc['updated_at'] = Util.getTimeStamp();

      Response response = await remoteDb.put('/$docId', data: newDoc);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Document updated successfully: $docId');
        return 'OK';
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Document conflict (409), resolving...');
        return await _resolveConflictAndRetry(remoteDb, docId, newDoc);
      } else {
        debugPrint('❌ Failed to update: ${response.statusCode}');
        return 'Error: ${response.statusMessage}';
      }
    } catch (err) {
      debugPrint('❌ Error updating document: $err');
      return 'Error: $err';
    }
  }

  Future<String> setComboData() async {
    try {
      debugPrint('📊 Setting combo data from remote...');

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        return 'Error: Could not resolve price_list database name';
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        return 'Error: Remote DB connection is null';
      }

      // ✅ Both maps use STRING keys (match Vue)
      Map<String, String> deptMap = {};
      Map<String, String> investMap = {}; // ✅ Changed from Map<int, String>

      Response response = await remoteDb.get(
        '/_all_docs',
        queryParameters: {
          'include_docs': true,
          'startkey': jsonEncode('price_list:abp:'),
          'endkey': jsonEncode('price_list:abp:\ufff0'),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null) {
            Map<String, dynamic> item = Map<String, dynamic>.from(row['doc']);

            // Department
            String deptName =
                (item['dept_name'] ?? '').toString().toLowerCase();
            String deptId = item['dept_id']?.toString() ?? '';

            if (deptName.isNotEmpty &&
                deptId.isNotEmpty &&
                !deptMap.containsKey(deptName)) {
              deptMap[deptName] = deptId;
            }

            // Investigation - ✅ Keep as STRING (match Vue)
            String investId = item['invest_id']?.toString() ?? '';
            String investName = item['invest_name']?.toString() ?? '';

            if (investId.isNotEmpty &&
                investName.isNotEmpty &&
                !investMap.containsKey(investId)) {
              investMap[investId] = investName;
            }
          }
        }
      }

      List<List<dynamic>> deptEntries =
          deptMap.entries.map((e) => [e.key, e.value]).toList();
      List<List<dynamic>> investEntries =
          investMap.entries.map((e) => [e.key, e.value]).toList();

      String deptJson = jsonEncode(deptEntries);
      String investJson = jsonEncode(investEntries);

      await _storage.saveSessionItem('dept_names', deptJson);
      await _storage.saveSessionItem('invest_names', investJson);

      debugPrint('✅ Combo data set successfully');
      debugPrint('   Departments: ${deptMap.length}');
      debugPrint('   Investigations: ${investMap.length}');

      // ✅ Only print first 100 chars
      debugPrint('Dept JSON: ${deptJson.substring(0, 100)}...');
      debugPrint('Invest JSON: ${investJson.substring(0, 100)}...');

      return 'OK';
    } catch (err, stackTrace) {
      debugPrint('❌ Error setting combo data: $err');
      return 'Error: $err';
    }
  }

  Future<Map<String, dynamic>?> getHistory() async {
    try {
      debugPrint('📜 Getting price list history from remote...');
      return await getOne('price_list:history');
    } catch (err) {
      debugPrint('❌ Error getting history: $err');
      return null;
    }
  }

  Future<String> insertHistory(Map<String, dynamic> thisHistory) async {
    try {
      debugPrint('📝 Inserting price list history to remote...');

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        return 'Error: Could not resolve price_list database name';
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        return 'Error: Remote DB connection is null';
      }

      Map<String, dynamic>? oldDoc = await getOne('price_list:history');

      if (oldDoc != null) {
        List<dynamic> oldHistory = oldDoc['history'] ?? [];
        oldHistory.insert(0, thisHistory); // unshift equivalent
        oldDoc['history'] = oldHistory;
        oldDoc['updated_at'] = Util.getTimeStamp();

        return await update(oldDoc);
      } else {
        Map<String, dynamic> doc = {
          '_id': 'price_list:history',
          'history': [thisHistory],
          'created_at': Util.getTimeStamp(),
          'updated_at': Util.getTimeStamp(),
        };
        return await insertNew(doc);
      }
    } catch (err) {
      debugPrint('❌ Error inserting history: $err');
      return 'Error: $err';
    }
  }

  Future<String> importData() async {
    try {
      debugPrint('📦 Importing CGHS data to remote...');

      String? name = _dbHandler.resolveName('price_list');
      if (name == null) {
        return 'Error: Could not resolve price_list database name';
      }

      Dio? remoteDb = await _couchDB.getDB(name);
      if (remoteDb == null) {
        return 'Error: Remote DB connection is null';
      }

      int line = 1;
      final cghsData = CghsData();

      Response response = await remoteDb.get(
        '/_all_docs',
        queryParameters: {
          'include_docs': true,
          'startkey': jsonEncode('price_list:abp:'),
          'endkey': jsonEncode('price_list:abp:\ufff0'),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null) {
            Map<String, dynamic> item = Map<String, dynamic>.from(row['doc']);
            int itemInvestId =
                int.tryParse(item['invest_id']?.toString() ?? '0') ?? 0;
            int? cghsPrice = cghsData.get(itemInvestId);

            if (cghsPrice != null && cghsPrice != 0) {
              item['cghs_price'] = cghsPrice.toString();
              String result = await update(item);

              if (result == 'OK') {
                debugPrint(
                    '$line ${item['cghs_price']} ${item['invest_name']}');
                line++;
              } else {
                debugPrint('⚠️ Failed to update item $line: $result');
              }
            }
          }
        }
      }

      debugPrint('✅ CGHS data import completed. Updated $line items.');
      return 'OK';
    } catch (err) {
      debugPrint('❌ Error importing data: $err');
      return 'Error: $err';
    }
  }

  Future<String> _resolveConflictAndRetry(
    Dio remoteDb,
    String docId,
    Map<String, dynamic> localDoc,
  ) async {
    try {
      debugPrint('🔄 Fetching remote document: $docId');

      Response getResponse = await remoteDb.get('/$docId');

      if (getResponse.statusCode == 200) {
        Map<String, dynamic> remoteDoc =
            Map<String, dynamic>.from(getResponse.data);
        String remoteRev = remoteDoc['_rev'];

        localDoc['_rev'] = remoteRev;

        Response retryResponse = await remoteDb.put('/$docId', data: localDoc);

        if (retryResponse.statusCode == 200 ||
            retryResponse.statusCode == 201) {
          debugPrint('✅ Document updated after conflict resolution');
          return 'OK';
        } else {
          return 'Error: Conflict resolution failed';
        }
      } else if (getResponse.statusCode == 404) {
        localDoc.remove('_rev');

        Response createResponse = await remoteDb.put('/$docId', data: localDoc);

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          debugPrint('✅ Document created successfully');
          return 'OK';
        } else {
          return 'Error: Failed to create document';
        }
      } else {
        return 'Error: Could not resolve conflict';
      }
    } catch (error) {
      debugPrint('❌ Error in conflict resolution: $error');
      return 'Error: $error';
    }
  }

  /// Helper: Add CGHS price to item
  Map<String, dynamic> _addCghsPrice(Map<String, dynamic> item) {
    if (item['history'] == null) {
      Map<String, dynamic> history = {
        'action': 'NA',
        'summary': 'Not Found',
        'emp_id': 'NA',
        'emp_name': 'NA',
        'emp_mobile': 'NA',
        'time_stamp': 'NA',
      };
      item['history'] = [history];
    }

    if (item['cghs_price'] == null) {
      item['cghs_price'] = '0';
    }

    return item;
  }

  /// Helper: Check if string is numeric
  bool _isNumeric(String str) {
    return double.tryParse(str) != null;
  }
}

// Provider for PriceListDB
final priceListDbProvider = Provider<PriceListDB>((ref) {
  final dbHandler = ref.watch(dbHandlerProvider);
  final couchDb = ref.watch(couchDbClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return PriceListDB(dbHandler, couchDb, storage);
});

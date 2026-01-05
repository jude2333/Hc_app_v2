// FILE: lib/providers/manager_price_list_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/priceList_db.dart';
import 'package:anderson_crm_flutter/util.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:flutter/foundation.dart';

Map<String, dynamic> _parseComboDataIsolate(Map<String, String> input) {
  final deptStr = input['dept_names'] ?? '';
  final investStr = input['invest_names'] ?? '';

  List<String> depts = [];
  Map<String, String> dMap = {};
  List<String> invNames = [];
  List<String> invIds = [];
  Map<String, String> idToName = {};
  Map<String, String> nameToId = {};

  try {
    if (deptStr.isNotEmpty) {
      final List<dynamic> parsed = jsonDecode(deptStr);
      for (var item in parsed) {
        if (item is List && item.length >= 2) {
          String name = item[0].toString();
          String id = item[1].toString();
          String titleName = _toTitleCaseIsolate(name);
          depts.add(titleName);
          dMap[name.toLowerCase()] = id;
        }
      }
    }

    if (investStr.isNotEmpty) {
      final List<dynamic> parsed = jsonDecode(investStr);
      for (var item in parsed) {
        if (item is List && item.length >= 2) {
          String id = item[0].toString();
          String name = item[1].toString();
          invIds.add(id);
          invNames.add(name);
          idToName[id] = name;
          nameToId[name] = id;
        }
      }
    }
  } catch (e) {
    debugPrint('Error parsing: $e');
  }

  return {
    'depts': depts,
    'deptMap': dMap,
    'invNames': invNames,
    'invIds': invIds,
    'idToName': idToName,
    'nameToId': nameToId,
  };
}

String _toTitleCaseIsolate(String text) {
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

// State Class
class ManagerPriceListState {
  final bool isLoading;
  final List<Map<String, dynamic>> items;
  final List<String> deptNames;
  final Map<String, String> deptMap;
  final List<String> investNames;
  final List<String> investIds;
  final List<Map<String, dynamic>> history;
  final Map<String, String> investIdToName;
  final Map<String, String> investNameToId;
  final String currentSearchQuery; // ✅ Track current search

  ManagerPriceListState({
    this.isLoading = false,
    this.items = const [],
    this.deptNames = const [],
    this.deptMap = const {},
    this.investNames = const [],
    this.investIds = const [],
    this.history = const [],
    this.investIdToName = const {},
    this.investNameToId = const {},
    this.currentSearchQuery = '',
  });

  ManagerPriceListState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? items,
    List<String>? deptNames,
    Map<String, String>? deptMap,
    List<String>? investNames,
    List<String>? investIds,
    List<Map<String, dynamic>>? history,
    Map<String, String>? investIdToName,
    Map<String, String>? investNameToId,
    String? currentSearchQuery,
  }) {
    return ManagerPriceListState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      deptNames: deptNames ?? this.deptNames,
      deptMap: deptMap ?? this.deptMap,
      investNames: investNames ?? this.investNames,
      investIds: investIds ?? this.investIds,
      history: history ?? this.history,
      investIdToName: investIdToName ?? this.investIdToName,
      investNameToId: investNameToId ?? this.investNameToId,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
    );
  }
}

// Notifier
class ManagerPriceListNotifier extends StateNotifier<ManagerPriceListState> {
  final Ref ref;

  ManagerPriceListNotifier(this.ref) : super(ManagerPriceListState());

  PriceListDB get _db => ref.read(priceListDbProvider);

  // ✅ Load combo data in isolate
  Future<void> loadComboData() async {
    debugPrint('📊 Loading combo data...');

    await _db.setComboData();

    final storage = ref.read(storageServiceProvider);
    final deptStr = await storage.getFromSessionAsync('dept_names');
    final investStr = await storage.getFromSessionAsync('invest_names');

    debugPrint('🔄 Parsing ${investStr.length} chars in isolate...');

    // ✅ Parse in background isolate
    final result = await compute(_parseComboDataIsolate, {
      'dept_names': deptStr,
      'invest_names': investStr,
    });

    state = state.copyWith(
      deptNames: List<String>.from(result['depts']),
      deptMap: Map<String, String>.from(result['deptMap']),
      investNames: List<String>.from(result['invNames']),
      investIds: List<String>.from(result['invIds']),
      investIdToName: Map<String, String>.from(result['idToName']),
      investNameToId: Map<String, String>.from(result['nameToId']),
    );

    debugPrint(
        '✅ Loaded ${state.deptNames.length} depts, ${state.investIds.length} investigations');
  }

  // ✅ Debounced search
  Future<void> search(String query) async {
    // Skip if same query
    if (state.currentSearchQuery == query && state.items.isNotEmpty) {
      debugPrint('⏭️ Skipping duplicate search: $query');
      return;
    }

    state = state.copyWith(isLoading: true, currentSearchQuery: query);

    try {
      final results = await _db.fetchAllDataRemote(query);
      final List<Map<String, dynamic>> typedResults =
          results.map((e) => Map<String, dynamic>.from(e)).toList();

      state = state.copyWith(items: typedResults, isLoading: false);
      debugPrint('✅ Search complete: ${typedResults.length} results');
    } catch (e) {
      debugPrint('❌ Search error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> addTest(Map<String, dynamic> formData) async {
    try {
      state = state.copyWith(isLoading: true);
      final storage = ref.read(storageServiceProvider);
      final timestamp = Util.getTodayWithTime();

      final history = {
        "action": "Created",
        "summary":
            "New Test Item Created: ${formData['invest_id']}(${formData['invest_name']})",
        "emp_id": storage.getFromSession('logged_in_emp_id'),
        "emp_name": storage.getFromSession('logged_in_emp_name'),
        "emp_mobile": storage.getFromSession('logged_in_mobile'),
        "time_stamp": timestamp,
      };

      final idDate = DateTime.now().toIso8601String().split('T')[0];
      final newId = "price_list:abp:$idDate:${Util.uuidv4()}";

      final doc = {
        "_id": newId,
        "dept_name": formData['dept_name'],
        "dept_id": formData['dept_id'],
        "invest_id": formData['invest_id'],
        "invest_name": Util.toTitleCase(formData['invest_name']),
        "rate_card_name": "ANDERSON BASE PRICE SEPT 2021",
        "base_cost": formData['base_cost'],
        "min_cost": formData['min_cost'],
        "cghs_price": formData['cghs_price'],
        "history": [history],
      };

      final result = await _db.insertNew(doc);
      if (result == "OK") {
        await _db.insertHistory(history);
        search(""); // Refresh list
        return "OK";
      }
      return result;
    } catch (e) {
      return "Error: $e";
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> updateTest(
      Map<String, dynamic> newValues, Map<String, dynamic> oldItem) async {
    try {
      state = state.copyWith(isLoading: true);
      final storage = ref.read(storageServiceProvider);

      final oldDoc = await _db.getOne(oldItem['_id']);
      if (oldDoc == null) return "Error: Document not found";

      final oldCghs = oldDoc['cghs_price'] ?? 0;
      String summary =
          "Test Item Updated: Invest Id:${oldDoc['invest_id']}(${oldDoc['invest_name']}). ";
      summary +=
          "Old Values => Base Cost:${oldDoc['base_cost']} Min.Cost:${oldDoc['min_cost']} CGHS:$oldCghs ";
      summary +=
          "New Values => Base Cost:${newValues['base_cost']} Min.Cost:${newValues['min_cost']} CGHS:${newValues['cghs_price']}";

      final history = {
        "action": "Updated",
        "summary": summary,
        "emp_id": storage.getFromSession('logged_in_emp_id'),
        "emp_name": storage.getFromSession('logged_in_emp_name'),
        "emp_mobile": storage.getFromSession('logged_in_mobile'),
        "time_stamp": Util.getTodayWithTime(),
      };

      oldDoc['base_cost'] = newValues['base_cost'];
      oldDoc['min_cost'] = newValues['min_cost'];
      oldDoc['cghs_price'] = newValues['cghs_price'];

      List<dynamic> docHistory = List.from(oldDoc['history'] ?? []);
      docHistory.insert(0, history);
      oldDoc['history'] = docHistory;

      final result = await _db.update(oldDoc);
      if (result == "OK") {
        await _db.insertHistory(history);
        search(state.currentSearchQuery); // Refresh with current query
        return "OK";
      }
      return result;
    } catch (e) {
      return "Error: $e";
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> deleteTest(Map<String, dynamic> item) async {
    try {
      state = state.copyWith(isLoading: true);
      final result = await _db.deleteOne(item['_id']);
      if (result == "OK") {
        final storage = ref.read(storageServiceProvider);
        final history = {
          "action": "Deleted",
          "summary":
              "Test Item Deleted: ${item['invest_id']}(${item['invest_name']})",
          "emp_id": storage.getFromSession('logged_in_emp_id'),
          "emp_name": storage.getFromSession('logged_in_emp_name'),
          "emp_mobile": storage.getFromSession('logged_in_mobile'),
          "time_stamp": Util.getTodayWithTime(),
        };
        await _db.insertHistory(history);
        search(state.currentSearchQuery);
        return "OK";
      }
      return result;
    } catch (e) {
      return "Error: $e";
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadGlobalHistory() async {
    state = state.copyWith(isLoading: true);
    final historyDoc = await _db.getHistory();
    if (historyDoc != null && historyDoc['history'] != null) {
      state = state.copyWith(
          history: List<Map<String, dynamic>>.from(historyDoc['history']),
          isLoading: false);
    } else {
      state = state.copyWith(history: [], isLoading: false);
    }
  }
}

final managerPriceListProvider =
    StateNotifierProvider<ManagerPriceListNotifier, ManagerPriceListState>(
        (ref) {
  return ManagerPriceListNotifier(ref);
});

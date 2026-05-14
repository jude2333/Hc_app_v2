import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../data/price_list_model.dart';
import '../data/price_list_repository.dart';

final priceListRepositoryProvider = Provider<PriceListRepository>((ref) {
  final db = PowerSyncService.instance.db;
  return PriceListRepository(db);
});

class PriceListState {
  final bool isLoading;
  final List<PriceListItem> items;
  final List<String> deptNames;
  final Map<String, String> deptMap;
  final List<String> investNames;
  final List<String> investIds;
  final Map<String, String> investIdToName;
  final Map<String, String> investNameToId;
  final List<Map<String, dynamic>> globalHistory;
  final String currentSearchQuery;
  final String? errorMessage;

  const PriceListState({
    this.isLoading = false,
    this.items = const [],
    this.deptNames = const [],
    this.deptMap = const {},
    this.investNames = const [],
    this.investIds = const [],
    this.investIdToName = const {},
    this.investNameToId = const {},
    this.globalHistory = const [],
    this.currentSearchQuery = '',
    this.errorMessage,
  });

  PriceListState copyWith({
    bool? isLoading,
    List<PriceListItem>? items,
    List<String>? deptNames,
    Map<String, String>? deptMap,
    List<String>? investNames,
    List<String>? investIds,
    Map<String, String>? investIdToName,
    Map<String, String>? investNameToId,
    List<Map<String, dynamic>>? globalHistory,
    String? currentSearchQuery,
    String? errorMessage,
  }) {
    return PriceListState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      deptNames: deptNames ?? this.deptNames,
      deptMap: deptMap ?? this.deptMap,
      investNames: investNames ?? this.investNames,
      investIds: investIds ?? this.investIds,
      investIdToName: investIdToName ?? this.investIdToName,
      investNameToId: investNameToId ?? this.investNameToId,
      globalHistory: globalHistory ?? this.globalHistory,
      currentSearchQuery: currentSearchQuery ?? this.currentSearchQuery,
      errorMessage: errorMessage,
    );
  }
}

class PriceListNotifier extends StateNotifier<PriceListState> {
  final Ref ref;

  PriceListNotifier(this.ref) : super(const PriceListState());

  PriceListRepository get _repo => ref.read(priceListRepositoryProvider);

  Future<void> init() async {
    if (state.items.isNotEmpty || state.deptNames.isNotEmpty) return;

    debugPrint(' [PriceListNotifier] init()');
    await loadComboData();
    await search('');
  }

  Future<void> loadComboData() async {
    debugPrint(' [PriceListNotifier] loadComboData()');

    try {
      final results = await Future.wait([
        _repo.getDepartmentMap(),
        _repo.getInvestigationMap(),
      ]);

      final deptMap = results[0];
      final investMap = results[1];

      final deptNames = deptMap.keys.map(_toTitleCase).toList();
      final investIds = investMap.keys.toList();
      final investNames = investMap.values.toList();

      final investNameToId = <String, String>{};
      investMap.forEach((id, name) {
        investNameToId[name] = id;
      });

      state = state.copyWith(
        deptNames: deptNames,
        deptMap: deptMap,
        investIds: investIds,
        investNames: investNames,
        investIdToName: investMap,
        investNameToId: investNameToId,
      );

      debugPrint(
          ' [PriceListNotifier] Loaded ${deptNames.length} depts, ${investIds.length} investigations');
    } catch (e) {
      debugPrint(' [PriceListNotifier] loadComboData error: $e');
      state = state.copyWith(errorMessage: 'Failed to load combo data: $e');
    }
  }

  Future<void> search(String query, {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        state.currentSearchQuery == query &&
        state.items.isNotEmpty) {
      debugPrint(' [PriceListNotifier] Skipping duplicate search: $query');
      return;
    }

    state = state.copyWith(isLoading: true, currentSearchQuery: query);

    try {
      final items = await _repo.fetchAll(query: query);
      state =
          state.copyWith(items: items, isLoading: false, errorMessage: null);
      debugPrint(
          ' [PriceListNotifier] Search complete: ${items.length} results');
    } catch (e) {
      debugPrint(' [PriceListNotifier] search error: $e');
      state =
          state.copyWith(isLoading: false, errorMessage: 'Search failed: $e');
    }
  }

  Future<String> addTest(Map<String, dynamic> formData) async {
    debugPrint(' [PriceListNotifier] addTest()');

    try {
      state = state.copyWith(isLoading: true);

      final storage = ref.read(storageServiceProvider);
      final empId = storage.getFromSession('logged_in_emp_id');
      final empName = storage.getFromSession('logged_in_emp_name');
      final empMobile = storage.getFromSession('logged_in_mobile');

      final item = PriceListItem.fromFormData(
        deptId: formData['dept_id']?.toString() ?? '',
        deptName: formData['dept_name']?.toString() ?? '',
        investId: formData['invest_id']?.toString() ?? '',
        investName: formData['invest_name']?.toString() ?? '',
        baseCost: formData['base_cost']?.toString() ?? '0',
        minCost: formData['min_cost']?.toString() ?? '0',
        cghsPrice: formData['cghs_price']?.toString() ?? '0',
        empId: empId,
        empName: empName,
        empMobile: empMobile,
        rateCardName: formData['rate_card_name'],
      );

      final result = await _repo.insert(item);

      if (result == 'OK') {
        await search('', forceRefresh: true);
        await loadGlobalHistory();
      }

      return result;
    } catch (e) {
      debugPrint(' [PriceListNotifier] addTest error: $e');
      return 'Error: $e';
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> updateTest(
      Map<String, dynamic> newValues, PriceListItem oldItem) async {
    debugPrint(' [PriceListNotifier] updateTest(${oldItem.id})');

    try {
      state = state.copyWith(isLoading: true);

      final storage = ref.read(storageServiceProvider);
      final empId = storage.getFromSession('logged_in_emp_id');
      final empName = storage.getFromSession('logged_in_emp_name');
      final empMobile = storage.getFromSession('logged_in_mobile');

      final summary =
          'Test Item Updated: Invest Id:${oldItem.investId}(${oldItem.investName}). '
          'Old Values => Base Cost:${oldItem.baseCost} Min.Cost:${oldItem.minCost} CGHS:${oldItem.cghsPrice} '
          'New Values => Base Cost:${newValues['base_cost']} Min.Cost:${newValues['min_cost']} CGHS:${newValues['cghs_price']}';

      final updatedItem = oldItem
          .addHistoryEntry(
            action: 'Updated',
            summary: summary,
            empId: empId,
            empName: empName,
            empMobile: empMobile,
          )
          .copyWith(
            baseCost:
                double.tryParse(newValues['base_cost']?.toString() ?? '0') ?? 0,
            minCost:
                double.tryParse(newValues['min_cost']?.toString() ?? '0') ?? 0,
            cghsPrice:
                double.tryParse(newValues['cghs_price']?.toString() ?? '0') ??
                    0,
          );

      final result = await _repo.update(updatedItem);

      if (result == 'OK') {
        await search(state.currentSearchQuery, forceRefresh: true);
        await loadGlobalHistory();
      }

      return result;
    } catch (e) {
      debugPrint(' [PriceListNotifier] updateTest error: $e');
      return 'Error: $e';
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> deleteTest(PriceListItem item) async {
    debugPrint(' [PriceListNotifier] deleteTest(${item.id})');

    try {
      state = state.copyWith(isLoading: true);

      final result = await _repo.softDelete(item.id);

      if (result == 'OK') {
        final currentQuery = state.currentSearchQuery;
        await search(currentQuery, forceRefresh: true);
        await loadGlobalHistory();
        debugPrint(' [PriceListNotifier] Delete successful, list refreshed');
      }

      return result;
    } catch (e) {
      debugPrint(' [PriceListNotifier] deleteTest error: $e');
      return 'Error: $e';
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadGlobalHistory() async {
    debugPrint(' [PriceListNotifier] loadGlobalHistory()');

    state = state.copyWith(isLoading: true);

    try {
      final history = await _repo.getGlobalHistory(limit: 200);
      state = state.copyWith(globalHistory: history, isLoading: false);
      debugPrint(
          ' [PriceListNotifier] Loaded ${history.length} history entries');
    } catch (e) {
      debugPrint(' [PriceListNotifier] loadGlobalHistory error: $e');
      state = state.copyWith(
          isLoading: false, errorMessage: 'Failed to load history: $e');
    }
  }

  String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

final priceListProvider =
    StateNotifierProvider<PriceListNotifier, PriceListState>((ref) {
  return PriceListNotifier(ref);
});

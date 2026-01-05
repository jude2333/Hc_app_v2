import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/priceList_db.dart';

final priceListProvider = StateNotifierProvider.autoDispose<PriceListNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return PriceListNotifier(ref);
});

class PriceListNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  Timer? _debounceTimer;

  PriceListNotifier(this.ref) : super(const AsyncValue.data([])) {
    search('');
  }

  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      search(query);
    });
  }

  Future<void> search(String query) async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(priceListDbProvider);

      final results = await db.fetchAllDataRemote(query);

      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

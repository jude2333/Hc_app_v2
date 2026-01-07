import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/pincode_db.dart';
import '../services/pincode_service.dart';
import '../providers/db_handler_provider.dart';
import '../providers/couch_db_provider.dart';

final pincodeDbProvider = Provider<PincodeDB>((ref) {
  final dbHandler = ref.watch(dbHandlerProvider);
  final couchDb = ref.watch(couchDbClientProvider);
  return PincodeDB(dbHandler, couchDb);
});

final pincodeServiceProvider = Provider<PincodeService>((ref) {
  final pincodeDb = ref.watch(pincodeDbProvider);
  return PincodeService(pincodeDb);
});

final pincodeResultsProvider =
    StateProvider<List<Map<String, dynamic>>>((ref) => []);

final pincodeLoadingProvider = StateProvider<bool>((ref) => false);

class PincodeNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final PincodeService _service;

  PincodeNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadInitialPincodes() async {
    state = const AsyncValue.loading();
    try {
      final results = await _service.getInitialPincodes();
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> searchPincodes(String query) async {
    if (query.isEmpty) {
      await loadInitialPincodes();
      return;
    }

    state = const AsyncValue.loading();
    try {
      final results = await _service.searchPincodes(query);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final pincodeNotifierProvider = StateNotifierProvider<PincodeNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final service = ref.watch(pincodeServiceProvider);
  return PincodeNotifier(service);
});

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';

List<Map<String, dynamic>> _parseResults(List<dynamic> rawData) {
  final List<Map<String, dynamic>> results = [];

  for (final item in rawData) {
    try {
      if (item is Map<String, dynamic>) {
        if (item.containsKey('hc_patient_visit_detail')) {
          final visits = item['hc_patient_visit_detail'] as List?;
          if (visits != null) {
            for (final visit in visits) {
              if (visit is Map && visit['doc'] != null) {
                final parsed = _parseDocString(visit['doc'].toString());
                if (parsed != null) results.add(parsed);
              }
            }
          }
        } else if (item.containsKey('doc')) {
          final parsed = _parseDocString(item['doc'].toString());
          if (parsed != null) results.add(parsed);
        } else {
          results.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('Error parsing result item: $e');
    }
  }

  results.sort((a, b) {
    try {
      final dateA = _parseDate(a['appointment_date']?.toString() ?? '');
      final dateB = _parseDate(b['appointment_date']?.toString() ?? '');
      return dateB.compareTo(dateA);
    } catch (e) {
      return 0;
    }
  });

  return results;
}

Map<String, dynamic>? _parseDocString(String docStr) {
  try {
    if (docStr.startsWith('{')) {
      return Map<String, dynamic>.from({});
    }
  } catch (e) {
    debugPrint('Error parsing doc string: $e');
  }
  return null;
}

DateTime _parseDate(String dateStr) {
  try {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        return DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } else {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    }
  } catch (e) {
    debugPrint('Error parsing date: $dateStr');
  }
  return DateTime(1970);
}

class SearchState {
  final List<Map<String, dynamic>> results;
  final bool isLoading;
  final String? error;
  final String searchType;
  final String query;
  final DateTime? selectedDate;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.searchType = 'Mobile',
    this.query = '',
    this.selectedDate,
  });

  SearchState copyWith({
    List<Map<String, dynamic>>? results,
    bool? isLoading,
    String? error,
    String? searchType,
    String? query,
    DateTime? selectedDate,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchType: searchType ?? this.searchType,
      query: query ?? this.query,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class SearchController extends StateNotifier<SearchState> {
  final Ref ref;
  Timer? _debounceTimer;

  SearchController(this.ref) : super(const SearchState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void setSearchType(String type) {
    state = state.copyWith(
      searchType: type,
      query: '',
      selectedDate: null,
      results: [],
      error: null,
    );
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setSelectedDate(DateTime? date) {
    state = state.copyWith(selectedDate: date);
    if (date != null) {
      search();
    }
  }

  void debounceSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      search();
    });
  }

  Future<void> search() async {
    final type = state.searchType;
    final query = state.query;
    final date = state.selectedDate;

    if (type == 'Mobile') {
      if (query.length != 10) {
        state = state.copyWith(
            error: 'Please enter a valid 10-digit mobile number');
        return;
      }
      final mobile = int.tryParse(query);
      if (mobile == null || mobile <= 999999999 || mobile >= 10000000000) {
        state = state.copyWith(error: 'Please enter a valid mobile number');
        return;
      }
    } else if (type == 'Date' && date == null) {
      state = state.copyWith(error: 'Please select a date');
      return;
    } else if (type == 'Name' && query.isEmpty) {
      state = state.copyWith(error: 'Please enter a name to search');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final postgresService = ref.read(postgresServiceProvider);
      final searchQuery = type == 'Date'
          ? '${date!.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : query;

      final rawResults =
          await postgresService.searchPatients(searchQuery, type);

      if (!mounted) return;

      final parsedResults = await compute(_parseResultsWrapper, rawResults);

      if (!mounted) return;

      if (parsedResults.isEmpty) {
        state = state.copyWith(
          results: [],
          isLoading: false,
          error: 'No data found for your search',
        );
      } else {
        state = state.copyWith(
          results: parsedResults,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Error: ${e.toString()}',
        );
      }
    }
  }

  void clearResults() {
    state = state.copyWith(results: [], error: null);
  }
}

List<Map<String, dynamic>> _parseResultsWrapper(dynamic rawData) {
  if (rawData is List) {
    return _parseResults(rawData);
  }
  return [];
}

final searchProvider =
    StateNotifierProvider<SearchController, SearchState>((ref) {
  return SearchController(ref);
});

final searchResultsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(searchProvider).results;
});

final searchLoadingProvider = Provider<bool>((ref) {
  return ref.watch(searchProvider.select((s) => s.isLoading));
});

final searchErrorProvider = Provider<String?>((ref) {
  return ref.watch(searchProvider.select((s) => s.error));
});

final expandedRowsProvider = StateProvider<Set<String>>((ref) => {});

final sortColumnProvider = StateProvider<String>((ref) => 'date');
final sortAscendingProvider = StateProvider<bool>((ref) => false);

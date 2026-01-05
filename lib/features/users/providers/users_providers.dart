import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import 'package:anderson_crm_flutter/features/users/data/user_model.dart';
import 'package:anderson_crm_flutter/features/users/data/users_repository.dart';
import 'package:anderson_crm_flutter/features/users/domain/users_service.dart';

// Repository Provider
final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final dbService = ref.watch(postgresServiceProvider);
  return UsersRepository(dbService);
});

// Service Provider
final usersServiceProvider = Provider<UsersService>((ref) {
  final repository = ref.watch(usersRepositoryProvider);
  return UsersService(repository);
});

// Pagination State
class UsersPaginationState {
  final int page;
  final int rowsPerPage;
  final String searchQuery;

  UsersPaginationState({
    this.page = 1,
    this.rowsPerPage = 50,
    this.searchQuery = '',
  });

  UsersPaginationState copyWith({
    int? page,
    int? rowsPerPage,
    String? searchQuery,
  }) {
    return UsersPaginationState(
      page: page ?? this.page,
      rowsPerPage: rowsPerPage ?? this.rowsPerPage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class UsersPaginationNotifier extends StateNotifier<UsersPaginationState> {
  UsersPaginationNotifier() : super(UsersPaginationState());

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void setRowsPerPage(int rows) {
    state = state.copyWith(rowsPerPage: rows, page: 1); // Reset to page 1
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, page: 1); // Reset to page 1
  }
}

final usersPaginationProvider =
    StateNotifierProvider<UsersPaginationNotifier, UsersPaginationState>((ref) {
  return UsersPaginationNotifier();
});

// Users List Provider
final usersListProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final pagination = ref.watch(usersPaginationProvider);
  final service = ref.watch(usersServiceProvider);

  // Keep the previous value while loading new data to avoid flicker
  // ref.keepAlive(); // Optional, but good for UX

  return service.getUsers(
    page: pagination.page,
    rowsPerPage: pagination.rowsPerPage,
    searchQuery: pagination.searchQuery,
  );
});

// Total count provider (mocked or fetched separately if API supports it)
// Since the original code mocked it or used list length, we might need a separate call or return a wrapper object.
// For now, let's assume the service returns just the list.
// If we need total count for pagination, we might need to adjust the service to return {data, total}.
// But the original code: `totalUsers: processedData.length < rowsPerPage ? processedData.length : 150`
// It seems it was mocking the total count.
// We can replicate this logic in the UI or a separate provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import 'package:anderson_crm_flutter/features/users/data/user_model.dart';
import 'package:anderson_crm_flutter/features/users/data/users_repository.dart';
import 'package:anderson_crm_flutter/features/users/domain/users_service.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final dbService = ref.watch(postgresServiceProvider);
  return UsersRepository(dbService);
});
final usersServiceProvider = Provider<UsersService>((ref) {
  final repository = ref.watch(usersRepositoryProvider);
  return UsersService(repository);
});

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
final usersListProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final pagination = ref.watch(usersPaginationProvider);
  final service = ref.watch(usersServiceProvider);

  return service.getUsers(
    page: pagination.page,
    rowsPerPage: pagination.rowsPerPage,
    searchQuery: pagination.searchQuery,
  );
});

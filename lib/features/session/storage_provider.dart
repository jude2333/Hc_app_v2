import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_repository.dart';
import 'storage_service.dart';

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final repository = StorageRepository();

  ref.onDispose(() {
    repository.dispose();
  });

  return repository;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final repo = ref.watch(storageRepositoryProvider);
  final service = StorageService(repo);

  Future.microtask(() => service.init());

  return service;
});

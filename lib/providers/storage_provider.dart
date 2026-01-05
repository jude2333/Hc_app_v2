// FILE: lib/providers/storage_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';

// ============================================
// PROVIDER 1: Repository (low-level)
// ============================================
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final repository = StorageRepository();

  // Dispose when no longer needed
  ref.onDispose(() {
    repository.dispose();
  });

  return repository;
});

// ============================================
// PROVIDER 2: Service (business logic)
// ============================================
// final storageServiceProvider = Provider<StorageService>((ref) {
//   final repository = ref.watch(storageRepositoryProvider);
//   return StorageService(repository);
// });

final storageServiceProvider = Provider<StorageService>((ref) {
  final repo = ref.watch(storageRepositoryProvider);
  final service = StorageService(repo);

  // ref.onDispose(service.dispose); // if needed

  // Fire and forget, provider lifecycle-safe
  Future.microtask(() => service.init());

  return service;
});

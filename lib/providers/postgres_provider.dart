import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/postgres_db.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/app_state.dart';

final postgresDbProvider = Provider<PostgresDB>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  return PostgresDB(
    storage,
    onStatusChange: (status) {
      ref.read(appNotifierProvider.notifier).setStatus(status);
    },
    onWorkOrderChange: (wo) {
      ref.read(appNotifierProvider.notifier).setWorkOrder(wo);
    },
    onTodayChange: (today) {
      ref.read(appNotifierProvider.notifier).setToday(today);
    },
  );
});

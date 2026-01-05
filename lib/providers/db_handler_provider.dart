import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/db_handler.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

import 'package:anderson_crm_flutter/providers/app_state.dart';

final dbHandlerProvider = Provider<DBHandler>((ref) {
  final storage = ref.watch(storageRepositoryProvider);

  return DBHandler(
    storage,
    onTodayChange: (today) {
      ref.read(appNotifierProvider.notifier).setToday(today);
    },
    onWorkOrderChange: null,
    onNotificationChange: null,
  );
});

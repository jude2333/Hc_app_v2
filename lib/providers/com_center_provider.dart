// FILE: lib/providers/com_center_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/com_center.dart';
import 'package:anderson_crm_flutter/services/com_center_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

// DB instance
final comCenterProvider = Provider<ComCenter>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  return ComCenter(storage);
});

// Service instance
final comCenterServiceProvider = Provider<ComCenterService>((ref) {
  final db = ref.watch(comCenterProvider);
  return ComCenterService(db);
});

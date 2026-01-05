// FILE: lib/providers/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/notification_center.dart';
import 'package:anderson_crm_flutter/services/notification_center_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

// Provider 1: Core NotificationCenter
final notificationCenterProvider = Provider<NotificationCenter>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationCenter(storage);
});

// Provider 2: Service wrapper (use this in widgets)
final notificationCenterServiceProvider =
    Provider<NotificationCenterService>((ref) {
  final notificationCenter = ref.watch(notificationCenterProvider);
  return NotificationCenterService(notificationCenter);
});

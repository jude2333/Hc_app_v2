import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/notification_center.dart';
import 'package:anderson_crm_flutter/services/notification_center_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

final notificationCenterProvider = Provider<NotificationCenter>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationCenter(storage);
});

final notificationCenterServiceProvider =
    Provider<NotificationCenterService>((ref) {
  final notificationCenter = ref.watch(notificationCenterProvider);
  return NotificationCenterService(notificationCenter);
});

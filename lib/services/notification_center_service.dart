import 'package:anderson_crm_flutter/database/notification_center.dart';

class NotificationCenterService {
  final NotificationCenter _notificationCenter;

  NotificationCenterService(this._notificationCenter);

  /// Send generic notification
  Future<String> sendNotification(Map<String, dynamic> notification) async {
    return await _notificationCenter.sendNotification(notification);
  }

  /// Send work order completed notification to manager
  Future<String> sendWorkOrderCompleted({
    required String appointmentDate,
    required String appointmentTime,
    required String patientName,
    required String age,
    required String gender,
    required String address,
    required String mobile,
    required String pincode,
    required String freeText,
    required String managerId,
    required String managerName,
  }) async {
    return await _notificationCenter.sendWorkOrderCompletedNotification(
      appointmentDate: appointmentDate,
      appointmentTime: appointmentTime,
      patientName: patientName,
      age: age,
      gender: gender,
      address: address,
      mobile: mobile,
      pincode: pincode,
      freeText: freeText,
      managerId: managerId,
      managerName: managerName,
    );
  }

  /// Send custom notification
  // Future<String> sendCustom({
  //   required String toId,
  //   required String toName,
  //   required String msgHeader,
  //   required String msgBody,
  //   Map<String, dynamic>? msgAttachment,
  // }) async {
  //   return await _notificationCenter.sendCustomNotification(
  //     toId: toId,
  //     toName: toName,
  //     msgHeader: msgHeader,
  //     msgBody: msgBody,
  //     msgAttachment: msgAttachment,
  //   );
  // }

  /// Refresh token
  Future<void> refreshToken() async {
    await _notificationCenter.refreshToken();
  }
}

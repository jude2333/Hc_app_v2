import 'package:anderson_crm_flutter/database/notification_center.dart';

class NotificationCenterService {
  final NotificationCenter _notificationCenter;

  NotificationCenterService(this._notificationCenter);

  Future<String> sendNotification(Map<String, dynamic> notification) async {
    return await _notificationCenter.sendNotification(notification);
  }

  // Future<String> sendWorkOrderCompleted({
  //   required String appointmentDate,
  //   required String appointmentTime,
  //   required String patientName,
  //   required String age,
  //   required String gender,
  //   required String address,
  //   required String mobile,
  //   required String pincode,
  //   required String freeText,
  //   required String managerId,
  //   required String managerName,
  // }) async {
  //   return await _notificationCenter.sendWorkOrderCompletedNotification(
  //     appointmentDate: appointmentDate,
  //     appointmentTime: appointmentTime,
  //     patientName: patientName,
  //     age: age,
  //     gender: gender,
  //     address: address,
  //     mobile: mobile,
  //     pincode: pincode,
  //     freeText: freeText,
  //     managerId: managerId,
  //     managerName: managerName,
  //   );
  // }

  Future<void> refreshToken() async {
    await _notificationCenter.refreshToken();
  }
}

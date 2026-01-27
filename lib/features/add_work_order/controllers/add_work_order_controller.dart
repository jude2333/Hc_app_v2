import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/core/util.dart';
import '../../../../models/work_order.dart';
import '../../../../providers/storage_provider.dart';
import '../../../../providers/work_order_provider.dart';
import '../../../../providers/com_center_provider.dart';
import '../../../../providers/notificationCenter_provider.dart';
import '../../../../config/settings.dart';

import '../../../../database/sms_template.dart';

final addWorkOrderControllerProvider =
    StateNotifierProvider<AddWorkOrderController, bool>((ref) {
  return AddWorkOrderController(ref);
});

class AddWorkOrderController extends StateNotifier<bool> {
  final Ref ref;

  AddWorkOrderController(this.ref) : super(false);

  void setLoading(bool loading) {
    state = loading;
  }

  Future<Map<String, dynamic>> saveWorkOrder({
    required bool isEditMode,
    required bool isCopyMode,
    WorkOrder? existingWorkOrder,
    required String collectionDate,
    required TimeOfDay? collectionTime,
    required String salutation,
    required String name,
    required String mobile,
    required String address,
    required String pincode,
    required String doctor,
    required String age,
    required String gender,
    required String email,
    required String freeText,
    required bool isVip,
    required bool isUrgent,
    required int credit,
    required int? b2bClientId,
    required String? b2bClientName,
    required bool sendSms,
    required bool sendWhatsapp,
    required bool sendEmail,
    required String prescriptionPath,
    required bool isCancelled,
    required String cancelReason,
  }) async {
    setLoading(true);

    try {
      final storage = ref.read(storageServiceProvider);
      final managerName = storage.getFromSession('logged_in_emp_name');

      DateTime calendar;
      try {
        calendar = DateFormat('EEEE d MMM yyyy').parse(collectionDate);
      } catch (e) {
        calendar = DateFormat('EEEE d MMMM yyyy').parse(collectionDate);
      }

      final visitTime =
          '${collectionTime!.hour.toString().padLeft(2, '0')}:${collectionTime!.minute.toString().padLeft(2, '0')}';
      final patientName = '$salutation. $name';

      if (isEditMode && existingWorkOrder != null) {
        final String status;
        final String serverStatus;
        final int? assignedId;
        final String assignedTo;

        if (isCancelled) {
          status = 'cancelled';
          serverStatus = 'cancelled';
          assignedId = existingWorkOrder.assignedId;
          assignedTo = existingWorkOrder.assignedTo;
        } else {
          status = 'unassigned';
          serverStatus = 'waiting';
          assignedId = null;
          assignedTo = '';
        }

        final updatedOrder = existingWorkOrder.copyWith(
          patientName: patientName,
          visitDate: calendar,
          visitTime: visitTime,
          doctorName: doctor,
          mobile: mobile,
          age: age,
          gender: gender,
          address: address,
          email: email,
          pincode: pincode,
          freeText: freeText,
          vip: isVip,
          urgent: isUrgent,
          credit: credit,
          b2bClientId: b2bClientId,
          b2bClientName: b2bClientName,
          status: status,
          serverStatus: serverStatus,
          assignedId: assignedId,
          assignedTo: assignedTo,
          settings: {
            'send_sms': sendSms ? 1 : 0,
            'send_whatsapp': sendWhatsapp ? 1 : 0,
            'send_email': sendEmail ? 1 : 0
          },
          lastUpdatedBy: managerName,
          lastUpdatedAt: DateTime.now(),
        );

        final now = DateTime.now();
        final log =
            "${DateFormat('MMMM dd, hh:mm a').format(now)} | $managerName | Work Order Updated";
        final timeline = List<dynamic>.from(existingWorkOrder.timeLine)
          ..add(log);

        if (isCancelled && existingWorkOrder.status != 'cancelled') {
          final cancelLog =
              "${DateFormat('MMMM dd, hh:mm a').format(now)} | $managerName | Work Order Cancelled";
          timeline.add(cancelLog);
        }

        final customDoc = updatedOrder.buildDoc();
        customDoc['time_line'] = timeline;

        if (isCancelled) {
          customDoc['cancel_reason'] = cancelReason;
        }

        final success = await ref
            .read(workOrderProvider)
            .updateWorkOrder(updatedOrder, customDoc: customDoc);

        if (success && isCancelled && existingWorkOrder.status != 'cancelled') {
          await _sendCancellationNotifications(
            workOrder: existingWorkOrder,
            sendSms: sendSms,
            sendWhatsapp: sendWhatsapp,
          );
        }

        setLoading(false);
        return {'success': success, 'message': 'Work Order Updated'};
      } else {
        final workOrder = WorkOrder.fromFormData(
          patientName: patientName,
          mobile: mobile,
          address: address,
          visitDate: calendar,
          visitTime: visitTime,
          managerId:
              int.tryParse(storage.getFromSession('logged_in_emp_id')) ?? 0,
          managerName: managerName,
          tenantId:
              int.tryParse(storage.getFromSession('logged_in_tenant_id')) ?? 0,
          salutation: salutation,
          age: age,
          gender: gender,
          email: email,
          pincode: pincode,
          doctorName: doctor,
          freeText: freeText,
          prescriptionPath: prescriptionPath,
          b2bClientId: b2bClientId,
          b2bClientName: b2bClientName,
          vip: isVip,
          urgent: isUrgent,
          credit: credit,
          sendSms: sendSms,
          sendWhatsapp: sendWhatsapp,
          sendEmail: sendEmail,
        );

        if (isCopyMode) {
          final log = "${Util.gettime()} - $managerName - Work Order Copied";
          final docMap = jsonDecode(workOrder.doc);
          docMap['time_line'] = [log];
          final finalOrder = workOrder.copyWith(doc: jsonEncode(docMap));

          final success =
              await ref.read(workOrderProvider).createWorkOrder(finalOrder);
          setLoading(false);
          return {
            'success': success,
            'message': 'Work Order Copied Successfully'
          };
        } else {
          final success =
              await ref.read(workOrderProvider).createWorkOrder(workOrder);

          if (success) {
            await _sendConfirmationSms(workOrder, sendSms);
          }

          setLoading(false);
          return {'success': success, 'message': 'Work Order Created'};
        }
      }
    } catch (e) {
      setLoading(false);
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<void> _sendConfirmationSms(WorkOrder workOrder, bool sendSms) async {
    if (!sendSms) {
      debugPrint(' Skipping SMS (user disabled SMS)');
      return;
    }

    try {
      final storage = ref.read(storageServiceProvider);
      final comCenter = ref.read(comCenterProvider);

      final idPart = Util.getRandomString(5);
      final centerId = storage.getFromSession('logged_in_tenant_id');
      final centerName = storage.getFromSession('logged_in_tenant_name');
      final departmentId = storage.getFromSession('department_id');
      final departmentName = storage.getFromSession('department_name');
      final roleId = storage.getFromSession('role_id');
      final roleName = storage.getFromSession('role_name');
      final empId = storage.getFromSession('logged_in_emp_id');
      final empName = storage.getFromSession('logged_in_emp_name');

      final appointmentDate =
          DateFormat('dd-MM-yyyy').format(workOrder.visitDate);

      final smsMessage = SmsTemplate.workorderConfirmation(appointmentDate);

      final message = {
        '_id': 'sms_center:$idPart:${Util.uuidv4()}',
        'center_id': centerId,
        'center_name': centerName,
        'department_id': departmentId,
        'department_name': departmentName,
        'role_id': roleId,
        'role_name': roleName,
        'emp_id': empId,
        'emp_name': empName,
        'recipient_mobile': workOrder.mobile,
        'recipient_name': workOrder.patientName,
        'status': '2',
        'message': smsMessage,
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      debugPrint(' Sending confirmation SMS to ${workOrder.mobile}');
      final result = await comCenter.sendMsg(message);

      if (result == 'OK') {
        debugPrint(' Confirmation SMS sent successfully');
      } else {
        debugPrint(' SMS sending failed: $result');
      }
    } catch (e) {
      debugPrint(' Error sending confirmation SMS: $e');
    }
  }

  Future<void> _sendCancellationNotifications({
    required WorkOrder workOrder,
    required bool sendSms,
    required bool sendWhatsapp,
  }) async {
    try {
      final storage = ref.read(storageServiceProvider);
      final comCenter = ref.read(comCenterProvider);
      final notificationCenter = ref.read(notificationCenterServiceProvider);

      if (workOrder.assignedTo.isNotEmpty) {
        final appointmentDate =
            DateFormat('dd-MM-yyyy').format(workOrder.visitDate);
        final msgHeader =
            "Cancelled Collection on $appointmentDate ${workOrder.visitTime}.";
        final msgBody =
            "Cancelled home collection for ${workOrder.patientName}(${workOrder.age}/${workOrder.gender}) "
            "address:${workOrder.address} mobile:${workOrder.mobile} pincode:${workOrder.pincode}"
            " ${workOrder.freeText}";

        final notification = {
          '_id': 'notifications:${Util.getDateForId()}:${Util.uuidv4()}',
          'from_id': storage.getFromSession('logged_in_emp_id'),
          'from_name': storage.getFromSession('logged_in_emp_name'),
          'to_id': workOrder.assignedId.toString(),
          'to_name': workOrder.assignedTo,
          'msg_header': msgHeader,
          'msg_body': msgBody,
          'msg_attachment': {},
          'status': 'New',
          'msg_time': Util.getTodayWithTime(),
          'updated_at': Util.getTimeStamp(),
        };

        debugPrint(
            ' Sending cancellation notification to ${workOrder.assignedTo}');
        final result = await notificationCenter.sendNotification(notification);
        if (result == 'OK') {
          debugPrint(' Cancellation notification sent to technician');
        } else {
          debugPrint(' Failed to send notification: $result');
        }
      }

      final rescheduleUrl = '${Settings.msgUrl}reschedule';

      final baseMessage = {
        'center_id': storage.getFromSession('logged_in_tenant_id'),
        'center_name': storage.getFromSession('logged_in_tenant_name'),
        'department_id': storage.getFromSession('department_id'),
        'department_name': storage.getFromSession('department_name'),
        'role_id': storage.getFromSession('role_id'),
        'role_name': storage.getFromSession('role_name'),
        'emp_id': storage.getFromSession('logged_in_emp_id'),
        'emp_name': storage.getFromSession('logged_in_emp_name'),
        'recipient_mobile': workOrder.mobile,
        'recipient_name': workOrder.patientName,
        'status': '0',
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      if (sendSms) {
        final smsMessage = Map<String, dynamic>.from(baseMessage);
        smsMessage['_id'] =
            'sms_center:${Util.getDateForId()}:${Util.uuidv4()}';
        smsMessage['message'] =
            SmsTemplate.homeCollectionCancellation(rescheduleUrl);

        debugPrint(' Sending cancellation SMS to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(smsMessage);
        if (result == 'OK') {
          debugPrint(' Cancellation SMS sent successfully');
        } else {
          debugPrint(' SMS failed: $result');
        }
      }

      if (sendWhatsapp) {
        final waMessage = Map<String, dynamic>.from(baseMessage);
        waMessage['_id'] =
            'whatsapp_center:${Util.getDateForId()}:${Util.uuidv4()}';
        waMessage['message'] = [rescheduleUrl];
        waMessage['template'] = 'hc_cancellation';

        debugPrint(' Sending cancellation WhatsApp to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(waMessage);
        if (result == 'OK') {
          debugPrint(' Cancellation WhatsApp sent successfully');
        } else {
          debugPrint(' WhatsApp failed: $result');
        }
      }
    } catch (e) {
      debugPrint(' Error sending cancellation notifications: $e');
    }
  }
}

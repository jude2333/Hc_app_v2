import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/database/sms_template.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/notificationCenter_provider.dart';
import 'package:anderson_crm_flutter/providers/com_center_provider.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';

import '../providers/manager_work_order_provider.dart';

class ManagerAssignmentController {
  final Ref _ref;

  ManagerAssignmentController(this._ref);

  dynamic get _storage => _ref.read(storageServiceProvider);
  PostgresService get _postgresService => _ref.read(postgresServiceProvider);
  ManagerWONotifier get _provider =>
      _ref.read(managerWONotifierProvider.notifier);

  Future<bool> assignTechnician({
    required WorkOrder workOrder,
    required String techId,
    required String techName,
  }) async {
    try {
      final managerName = _storage.getFromSession("logged_in_emp_name");

      final isReassignment = workOrder.assignedTo.isNotEmpty;

      final updatedOrder = workOrder.copyWith(
        assignedId: int.tryParse(techId) ?? 0,
        assignedTo: techName,
        status: 'assigned',
        lastUpdatedBy: managerName,
        lastUpdatedAt: DateTime.now(),
      );

      final now = DateTime.now();
      final formattedDate = DateFormat('MMMM dd, hh:mm a').format(now);
      final assignmentLog = isReassignment
          ? "$formattedDate | $managerName | Re-assigned To $techName (prev: ${workOrder.assignedTo})"
          : "$formattedDate | $managerName | Assigned To $techName";
      final existingTimeline = List<String>.from(workOrder.timeLine);
      existingTimeline.add(assignmentLog);

      final customDoc = updatedOrder.buildDoc();
      customDoc['time_line'] = existingTimeline;

      if (isReassignment) {
        customDoc['prev_assigned_to'] = workOrder.assignedTo;
        customDoc['prev_assigned_id'] = workOrder.assignedId;
      }

      await _provider.updateWorkOrder(updatedOrder, customDoc: customDoc);

      
      
      await _provider.syncAfterMutation();

      debugPrint(" About to send in-app notification...");
      await sendInAppNotification(workOrder, techId, techName);

      return true;
    } catch (e) {
      debugPrint(" Error assigning technician: $e");
      return false;
    }
  }

  Future<void> sendInAppNotification(
      WorkOrder workOrder, String techId, String techName) async {
    try {
      final notificationCenter = _ref.read(notificationCenterServiceProvider);

      final appointmentDate =
          DateFormat('dd-MM-yyyy').format(workOrder.visitDate);
      final msgHeader =
          "Collection on $appointmentDate ${workOrder.visitTime} assigned.";
      final msgBody = "Home collection for ${workOrder.patientName}"
          "(${workOrder.age}/${workOrder.gender}) "
          "address:${workOrder.address} mobile:${workOrder.mobile} pincode:${workOrder.pincode}"
          " ${workOrder.freeText}";

      debugPrint(" Sending notification to techId=$techId, techName=$techName");

      final notification = {
        '_id': 'notifications:${Util.getDateForId()}:${Util.uuidv4()}',
        'from_id': _storage.getFromSession('logged_in_emp_id'),
        'from_name': _storage.getFromSession('logged_in_emp_name'),
        'to_id': techId,
        'to_name': techName,
        'msg_header': msgHeader,
        'msg_body': msgBody,
        'msg_attachment': {},
        'status': 'New',
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      final result = await notificationCenter.sendNotification(notification);

      if (result == "OK") {
        debugPrint(" In-app notification sent to $techName");
      } else {
        debugPrint(" Failed to send in-app notification: $result");
      }
    } catch (e) {
      debugPrint(" Error sending in-app notification: $e");
    }
  }

  Future<Map<String, String>> getTechnicianDetails(String techId) async {
    return await _postgresService.getTechnicianById(techId);
  }

  Future<void> sendAssignmentMessages({
    required WorkOrder workOrder,
    required String techId,
    required String techName,
    required bool sendSms,
    required bool sendWhatsApp,
    required bool sendEmail,
    required bool isReassignment,
  }) async {
    try {
      final comCenter = _ref.read(comCenterProvider);

      final techDetails = await getTechnicianDetails(techId);
      final techMobile = techDetails['mobile'] ?? '';
      final s3Loc = techDetails['id_card_location'] ?? '';

      final idPart = Util.getRandomString(5);
      final msgUrl = '${Settings.msgUrl}$idPart';

      final baseMessage = {
        'center_id': _storage.getFromSession('logged_in_tenant_id'),
        'center_name': _storage.getFromSession('logged_in_tenant_name'),
        'department_id': _storage.getFromSession('department_id'),
        'department_name': _storage.getFromSession('department_name'),
        'role_id': _storage.getFromSession('role_id'),
        'role_name': _storage.getFromSession('role_name'),
        'emp_id': _storage.getFromSession('logged_in_emp_id'),
        'emp_name': _storage.getFromSession('logged_in_emp_name'),
        'recipient_mobile': workOrder.mobile,
        'recipient_name': workOrder.patientName,
        'status': '0',
        's3_loc': s3Loc,
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      if (sendSms && !Settings.development) {
        String smsMsg;
        if (isReassignment) {
          smsMsg = SmsTemplate.homeCollectionTechChange(
              techName, techMobile, msgUrl);
        } else {
          final appTime =
              "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}";
          smsMsg = SmsTemplate.sampleCollection(
              workOrder.patientName, techName, appTime, techMobile, msgUrl);
        }

        final smsMessage = Map<String, dynamic>.from(baseMessage);
        smsMessage['_id'] = 'sms_center:$idPart:${Util.uuidv4()}';
        smsMessage['message'] = smsMsg;

        debugPrint(' Sending assignment SMS to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(smsMessage);
        if (result == 'OK') {
          debugPrint(' SMS sent successfully');
        } else {
          debugPrint(' SMS failed: $result');
        }
      }

      if (sendWhatsApp) {
        List<String> whatsappMsg;
        String template;

        if (isReassignment) {
          whatsappMsg = [techName, techMobile, msgUrl];
          template = 'Technician_change_for_hc';
        } else {
          final appTime =
              "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}";
          whatsappMsg = [
            workOrder.patientName,
            techName,
            appTime,
            techMobile,
            msgUrl
          ];
          template = 'hc_technician_allocation3';
        }

        final waMessage = Map<String, dynamic>.from(baseMessage);
        waMessage['_id'] = 'whatsapp_center:$idPart:${Util.uuidv4()}';
        waMessage['message'] = whatsappMsg;
        waMessage['template'] = template;

        debugPrint(' Sending assignment WhatsApp to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(waMessage);
        if (result == 'OK') {
          debugPrint(' WhatsApp sent successfully');
        } else {
          debugPrint(' WhatsApp failed: $result');
        }
      }

      if (sendEmail) {
        final emailMessage = Map<String, dynamic>.from(baseMessage);
        emailMessage['_id'] = 'email_center:$idPart:${Util.uuidv4()}';

        debugPrint(' Sending assignment Email to ${workOrder.email}');
        final result = await comCenter.sendMsg(emailMessage);
        if (result == 'OK') {
          debugPrint(' Email sent successfully');
        } else {
          debugPrint(' Email failed: $result');
        }
      }

      if (workOrder.marketingPersonNumber.isNotEmpty &&
          workOrder.marketingPersonNumber.length >= 10) {
        final mktBaseMessage = Map<String, dynamic>.from(baseMessage);
        mktBaseMessage['recipient_mobile'] = workOrder.marketingPersonNumber;
        mktBaseMessage['recipient_name'] =
            workOrder.marketingPersonName.isNotEmpty
                ? workOrder.marketingPersonName
                : 'Marketing Person';

        if (sendSms && !Settings.development) {
          final smsMessage = Map<String, dynamic>.from(mktBaseMessage);
          smsMessage['_id'] =
              'sms_center:${Util.getRandomString(5)}:${Util.uuidv4()}';
          String smsMsg = isReassignment
              ? SmsTemplate.homeCollectionTechChange(
                  techName, techMobile, msgUrl)
              : SmsTemplate.sampleCollection(
                  workOrder.patientName,
                  techName,
                  "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}",
                  techMobile,
                  msgUrl);
          smsMessage['message'] = smsMsg;
          debugPrint(
              ' Sending assignment SMS to marketing person ${workOrder.marketingPersonNumber}');
          await comCenter.sendMsg(smsMessage);
        }

        if (sendWhatsApp) {
          final waMessage = Map<String, dynamic>.from(mktBaseMessage);
          waMessage['_id'] =
              'whatsapp_center:${Util.getRandomString(5)}:${Util.uuidv4()}';
          waMessage['template'] = isReassignment
              ? 'Technician_change_for_hc'
              : 'hc_technician_allocation3';
          waMessage['message'] = isReassignment
              ? [techName, techMobile, msgUrl]
              : [
                  workOrder.patientName,
                  techName,
                  "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}",
                  techMobile,
                  msgUrl
                ];

          debugPrint(
              ' Sending assignment WhatsApp to marketing person ${workOrder.marketingPersonNumber}');
          await comCenter.sendMsg(waMessage);
        }
      }
    } catch (e) {
      debugPrint(' Error sending assignment messages: $e');
      rethrow;
    }
  }

  
  
  Future<void> sendCancellationMessages({
    required WorkOrder workOrder,
    required bool sendSms,
    required bool sendWhatsApp,
    required bool sendEmail,
  }) async {
    try {
      final comCenter = _ref.read(comCenterProvider);

      
      if (workOrder.assignedTo.isNotEmpty) {
        final notificationCenter = _ref.read(notificationCenterServiceProvider);

        final appointmentDate =
            DateFormat('dd-MM-yyyy').format(workOrder.visitDate);
        final msgHeader =
            "Cancelled Collection on $appointmentDate ${workOrder.visitTime}.";
        final msgBody = "Cancelled home collection for ${workOrder.patientName}"
            "(${workOrder.age}/${workOrder.gender}) "
            "address:${workOrder.address} mobile:${workOrder.mobile} pincode:${workOrder.pincode}"
            " ${workOrder.freeText}";

        final notification = {
          '_id': 'notifications:${Util.getDateForId()}:${Util.uuidv4()}',
          'from_id': _storage.getFromSession('logged_in_emp_id'),
          'from_name': _storage.getFromSession('logged_in_emp_name'),
          'to_id': workOrder.assignedId.toString(),
          'to_name': workOrder.assignedTo,
          'msg_header': msgHeader,
          'msg_body': msgBody,
          'msg_attachment': {},
          'status': 'New',
          'msg_time': Util.getTodayWithTime(),
          'updated_at': Util.getTimeStamp(),
        };

        final result = await notificationCenter.sendNotification(notification);
        debugPrint(result == "OK"
            ? ' Cancellation notification sent to ${workOrder.assignedTo}'
            : ' Failed to send cancellation notification: $result');
      }

      
      final rescheduleUrl = '${Settings.msgUrl}reshedule';

      final baseMessage = {
        'center_id': _storage.getFromSession('logged_in_tenant_id'),
        'center_name': _storage.getFromSession('logged_in_tenant_name'),
        'department_id': _storage.getFromSession('department_id'),
        'department_name': _storage.getFromSession('department_name'),
        'role_id': _storage.getFromSession('role_id'),
        'role_name': _storage.getFromSession('role_name'),
        'emp_id': _storage.getFromSession('logged_in_emp_id'),
        'emp_name': _storage.getFromSession('logged_in_emp_name'),
        'recipient_mobile': workOrder.mobile,
        'recipient_name': workOrder.patientName,
        'status': '0',
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      
      if (sendSms) {
        if (Settings.development) {
          debugPrint(' Skipping cancellation SMS in development mode');
        } else {
          final smsMsg = SmsTemplate.homeCollectionCancellation(rescheduleUrl);
          final smsMessage = Map<String, dynamic>.from(baseMessage);
          smsMessage['_id'] =
              'sms_center:${Util.getDateForId()}:${Util.uuidv4()}';
          smsMessage['message'] = smsMsg;

          debugPrint(' Sending cancellation SMS to ${workOrder.mobile}');
          final result = await comCenter.sendMsg(smsMessage);
          debugPrint(result == 'OK'
              ? ' Cancellation SMS sent'
              : ' Cancellation SMS failed: $result');
        }
      }

      
      if (sendWhatsApp) {
        final waMessage = Map<String, dynamic>.from(baseMessage);
        waMessage['_id'] =
            'whatsapp_center:${Util.getDateForId()}:${Util.uuidv4()}';
        waMessage['message'] = [rescheduleUrl];
        waMessage['template'] = 'hc_cancellation';

        debugPrint(' Sending cancellation WhatsApp to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(waMessage);
        debugPrint(result == 'OK'
            ? ' Cancellation WhatsApp sent'
            : ' Cancellation WhatsApp failed: $result');
      }

      
      if (sendEmail) {
        final emailMessage = Map<String, dynamic>.from(baseMessage);
        emailMessage['_id'] =
            'email_center:${Util.getDateForId()}:${Util.uuidv4()}';

        debugPrint(' Sending cancellation Email to ${workOrder.email}');
        final result = await comCenter.sendMsg(emailMessage);
        debugPrint(result == 'OK'
            ? ' Cancellation Email sent'
            : ' Cancellation Email failed: $result');
      }
    } catch (e) {
      debugPrint(' Error sending cancellation messages: $e');
      rethrow;
    }
  }
}

final managerAssignmentControllerProvider =
    Provider<ManagerAssignmentController>((ref) {
  return ManagerAssignmentController(ref);
});

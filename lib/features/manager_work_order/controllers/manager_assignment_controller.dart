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

/// Controller for Manager Work Order assignment logic
/// Matches Vue desktop_view.vue logic exactly for SMS/WhatsApp/Email sending
class ManagerAssignmentController {
  final Ref _ref;

  ManagerAssignmentController(this._ref);

  dynamic get _storage => _ref.read(storageServiceProvider);
  PostgresService get _postgresService => _ref.read(postgresServiceProvider);
  ManagerWorkOrderProvider get _provider => _ref.read(managerWorkOrderProvider);

  /// Assign technician to work order
  /// Matches Vue's selected_tech() function (line 662-697)
  Future<bool> assignTechnician({
    required WorkOrder workOrder,
    required String techId,
    required String techName,
  }) async {
    try {
      final managerName = _storage.getFromSession("logged_in_emp_name");

      // Check if this is a re-assignment (Vue: doc.prev_assigned_to)
      final isReassignment = workOrder.assignedTo.isNotEmpty;

      final updatedOrder = workOrder.copyWith(
        assignedId: int.tryParse(techId) ?? 0,
        assignedTo: techName,
        status: 'assigned',
        lastUpdatedBy: managerName,
        lastUpdatedAt: DateTime.now(),
      );

      // Build timeline entry (Vue: workorder_assigned variable)
      final now = DateTime.now();
      final formattedDate = DateFormat('MMMM dd, hh:mm a').format(now);
      final assignmentLog = isReassignment
          ? "$formattedDate | $managerName | Re-assigned To $techName (prev: ${workOrder.assignedTo})"
          : "$formattedDate | $managerName | Assigned To $techName";
      final existingTimeline = List<String>.from(workOrder.timeLine);
      existingTimeline.add(assignmentLog);

      // Build custom doc with prev_assigned tracking (Vue: doc.prev_assigned_to/id)
      final customDoc = updatedOrder.buildDoc();
      customDoc['time_line'] = existingTimeline;

      if (isReassignment) {
        customDoc['prev_assigned_to'] = workOrder.assignedTo;
        customDoc['prev_assigned_id'] = workOrder.assignedId;
      }

      await _provider.updateWorkOrder(updatedOrder, customDoc: customDoc);

      // Send in-app notification (mirrors Vue's send_notification)
      debugPrint("🔔 About to send in-app notification...");
      await sendInAppNotification(workOrder, techId, techName);

      return true;
    } catch (e) {
      debugPrint("❌ Error assigning technician: $e");
      return false;
    }
  }

  /// Send in-app notification to technician
  /// Matches Vue's send_notification() function (line 538-567)
  Future<void> sendInAppNotification(
      WorkOrder workOrder, String techId, String techName) async {
    try {
      final notificationCenter = _ref.read(notificationCenterServiceProvider);

      // Match Vue notification format exactly
      final appointmentDate =
          DateFormat('dd-MM-yyyy').format(workOrder.visitDate);
      final msgHeader =
          "Collection on $appointmentDate ${workOrder.visitTime} assigned.";
      final msgBody = "Home collection for ${workOrder.patientName}"
          "(${workOrder.age}/${workOrder.gender}) "
          "address:${workOrder.address} mobile:${workOrder.mobile} pincode:${workOrder.pincode}"
          " ${workOrder.freeText}";

      debugPrint(
          "📤 Sending notification to techId=$techId, techName=$techName");

      // Build notification payload matching Vue format exactly
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
        debugPrint("✅ In-app notification sent to $techName");
      } else {
        debugPrint("⚠️ Failed to send in-app notification: $result");
      }
    } catch (e) {
      debugPrint("❌ Error sending in-app notification: $e");
    }
  }

  /// Get technician mobile and ID card location
  /// Matches Vue's loop through technician_details (line 576-585)
  Future<Map<String, String>> getTechnicianDetails(String techId) async {
    return await _postgresService.getTechnicianById(techId);
  }

  /// Send assignment SMS/WhatsApp/Email messages
  /// Matches Vue's ok_msg_dialog() function (line 569-660) EXACTLY
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

      // Vue line 576-585: Get tech mobile and s3_loc from technician_details
      final techDetails = await getTechnicianDetails(techId);
      final techMobile = techDetails['mobile'] ?? '';
      final s3Loc = techDetails['id_card_location'] ?? '';

      // Vue line 589-590: Generate ID part and msg URL
      final idPart = Util.getRandomString(5);
      final msgUrl = '${Settings.msgUrl}$idPart';

      // Vue line 591-606: Build base message object
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
        's3_loc': s3Loc, // Tech ID card location - WAS MISSING!
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      // Vue line 608-626: Send SMS
      if (sendSms) {
        String smsMsg;
        if (isReassignment) {
          // Vue line 611: home_collection_tech_change template
          smsMsg = SmsTemplate.homeCollectionTechChange(
              techName, techMobile, msgUrl);
        } else {
          // Vue line 613-614: sample_collection template
          final appTime =
              "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}";
          smsMsg = SmsTemplate.sampleCollection(
              workOrder.patientName, techName, appTime, techMobile, msgUrl);
        }

        final smsMessage = Map<String, dynamic>.from(baseMessage);
        smsMessage['_id'] = 'sms_center:$idPart:${Util.uuidv4()}';
        smsMessage['message'] = smsMsg;

        debugPrint('📤 Sending assignment SMS to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(smsMessage);
        if (result == 'OK') {
          debugPrint('✅ SMS sent successfully');
        } else {
          debugPrint('⚠️ SMS failed: $result');
        }
      }

      // Vue line 627-649: Send WhatsApp
      if (sendWhatsApp) {
        List<String> whatsappMsg;
        String template;

        if (isReassignment) {
          // Vue line 631-632: Technician_change_for_hc template
          whatsappMsg = [techName, techMobile, msgUrl];
          template = 'Technician_change_for_hc';
        } else {
          // Vue line 634-636: hc_technician_allocation3 template
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

        debugPrint('📤 Sending assignment WhatsApp to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(waMessage);
        if (result == 'OK') {
          debugPrint('✅ WhatsApp sent successfully');
        } else {
          debugPrint('⚠️ WhatsApp failed: $result');
        }
      }

      // Vue line 650-659: Send Email
      if (sendEmail) {
        final emailMessage = Map<String, dynamic>.from(baseMessage);
        emailMessage['_id'] = 'email_center:$idPart:${Util.uuidv4()}';

        debugPrint('📤 Sending assignment Email to ${workOrder.email}');
        final result = await comCenter.sendMsg(emailMessage);
        if (result == 'OK') {
          debugPrint('✅ Email sent successfully');
        } else {
          debugPrint('⚠️ Email failed: $result');
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending assignment messages: $e');
      rethrow;
    }
  }
}

// Provider for the assignment controller
final managerAssignmentControllerProvider =
    Provider<ManagerAssignmentController>((ref) {
  return ManagerAssignmentController(ref);
});

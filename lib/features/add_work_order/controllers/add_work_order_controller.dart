import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../features/core/util.dart';
import '../../../../models/work_order.dart';
import '../../../../providers/storage_provider.dart';
import '../../../../features/manager_work_order/repositories/manager_work_order_repository.dart';
import '../../../../features/manager_work_order/providers/manager_work_order_provider.dart';
import '../../../../providers/com_center_provider.dart';
import '../../../../providers/notificationCenter_provider.dart';
import '../../../../config/settings.dart';
import '../../../../repositories/temp_upload_repository.dart';

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
    WorkOrder? copyFrom,
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
    required bool isCghs,
    required int credit,
    required int? b2bClientId,
    required String? b2bClientName,
    required String? marketingPersonName,
    required String? marketingPersonNumber,
    required String? alternateMobile,
    required String? clientCode,
    required String? doctorCode,
    required bool sendSms,
    required bool sendWhatsapp,
    required bool sendEmail,
    required List<String> prescriptionPaths,
    List<XFile> prescriptionImages = const [],
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
          prescriptionPath:
              prescriptionPaths.isNotEmpty ? prescriptionPaths.join(',') : null,
          vip: isVip,
          urgent: isUrgent,
          cghsClient: isCghs,
          credit: credit,
          b2bClientId: b2bClientId,
          b2bClientName: b2bClientName,
          marketingPersonName: marketingPersonName,
          marketingPersonNumber: marketingPersonNumber,
          alternateMobile: alternateMobile,
          clientCode: clientCode,
          doctorCode: doctorCode,
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

        // Upload new prescription images directly to S3
        // prescriptionPaths = [old1, old2, ..., new1, new2]
        // prescriptionImages = [XFile(new1), XFile(new2)]
        // New paths start at offset = total paths - new images count
        if (prescriptionImages.isNotEmpty && prescriptionPaths.isNotEmpty) {
          final offset = prescriptionPaths.length - prescriptionImages.length;
          for (int i = 0; i < prescriptionImages.length; i++) {
            final pathIndex = offset + i;
            if (pathIndex >= 0 && pathIndex < prescriptionPaths.length) {
              await _uploadPrescriptionToS3(
                prescriptionImage: prescriptionImages[i],
                prescriptionPath: prescriptionPaths[pathIndex],
              );
            }
          }
        }

        final success = await ref
            .read(managerWorkOrderRepositoryProvider)
            .updateWorkOrder(updatedOrder, customDoc: customDoc);

        setLoading(false);

        if (success) {
          // Fire-and-forget: PowerSync db.watch() will update the list reactively
          unawaited(
              ref.read(managerWONotifierProvider.notifier).syncAfterMutation());

          if (isCancelled && existingWorkOrder.status != 'cancelled') {
            unawaited(_sendCancellationNotifications(
              workOrder: existingWorkOrder,
              sendSms: sendSms,
              sendWhatsapp: sendWhatsapp,
            ));
          }
        }

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
          prescriptionPaths: prescriptionPaths,
          b2bClientId: b2bClientId,
          b2bClientName: b2bClientName,
          marketingPersonName: marketingPersonName,
          marketingPersonNumber: marketingPersonNumber,
          alternateMobile: alternateMobile,
          clientCode: clientCode,
          doctorCode: doctorCode,
          vip: isVip,
          urgent: isUrgent,
          cghsClient: isCghs,
          credit: credit,
          sendSms: sendSms,
          sendWhatsapp: sendWhatsapp,
          sendEmail: sendEmail,
        );

        // Upload prescription images directly to S3
        if (prescriptionImages.isNotEmpty && prescriptionPaths.isNotEmpty) {
          for (int i = 0; i < prescriptionImages.length; i++) {
            if (i < prescriptionPaths.length) {
              await _uploadPrescriptionToS3(
                prescriptionImage: prescriptionImages[i],
                prescriptionPath: prescriptionPaths[i],
              );
            }
          }
        }

        if (isCopyMode) {
          final log = "${Util.gettime()} - $managerName - Work Order Copied";
          final docMap = jsonDecode(workOrder.doc);
          docMap['time_line'] = [log];

          final String finalAssignedTo = copyFrom?.assignedTo ?? '';
          final int? finalAssignedId = copyFrom?.assignedId;
          final String finalStatus =
              finalAssignedTo.isNotEmpty ? 'assigned' : 'unassigned';
          final String finalServerStatus = 'waiting';

          docMap['status'] = finalStatus;
          docMap['server_status'] = finalServerStatus;
          docMap['assigned_to'] = finalAssignedTo;
          docMap['assigned_id'] = finalAssignedId;

          final finalOrder = workOrder.copyWith(
            doc: jsonEncode(docMap),
            status: finalStatus,
            serverStatus: finalServerStatus,
            assignedTo: finalAssignedTo,
            assignedId: finalAssignedId,
          );

          final success = await ref
              .read(managerWorkOrderRepositoryProvider)
              .createWorkOrder(finalOrder);

          setLoading(false);

          if (success) {
            // Fire-and-forget: list updates via db.watch()
            unawaited(ref
                .read(managerWONotifierProvider.notifier)
                .syncAfterMutation());
          }

          return {
            'success': success,
            'message': 'Work Order Copied Successfully'
          };
        } else {
          final success = await ref
              .read(managerWorkOrderRepositoryProvider)
              .createWorkOrder(workOrder);

          setLoading(false);

          if (success) {
            // Fire-and-forget: list updates via db.watch(), SMS is best-effort
            unawaited(ref
                .read(managerWONotifierProvider.notifier)
                .syncAfterMutation());
            unawaited(_sendConfirmationSms(workOrder, sendSms));
          }

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

  // Commented out to use direct S3 upload via Node API
  // /// Save prescription image to temp_uploads for S3 upload via hc_app_local
  // Future<void> _savePrescriptionToTempUploads({
  //   required String workOrderDocId,
  //   required XFile prescriptionImage,
  //   required String prescriptionPath,
  // }) async {
  //   try {
  //     final storage = ref.read(storageServiceProvider);
  //     final tempUploadRepo = ref.read(tempUploadRepositoryProvider);
  // 
  //     final bytes = await prescriptionImage.readAsBytes();
  //     final fileName = prescriptionImage.name;
  // 
  //     debugPrint('Saving prescription to temp_uploads: $fileName');
  // 
  //     await tempUploadRepo.saveOfflinePhoto(
  //       workOrderId: workOrderDocId,
  //       fileName: fileName,
  //       fileLocation: prescriptionPath,
  //       fileBytes: bytes,
  //       tenantId: int.tryParse(storage.getFromSession('logged_in_tenant_id')),
  //       createdBy: int.tryParse(storage.getFromSession('logged_in_emp_id')),
  //     );
  // 
  //     debugPrint(' Prescription saved to temp_uploads: $workOrderDocId');
  //   } catch (e) {
  //     debugPrint(' Failed to save prescription to temp_uploads: $e');
  //     // Don't throw - allow work order creation to continue
  //   }
  // }

  /// Upload prescription image directly to S3 via Node API
  Future<void> _uploadPrescriptionToS3({
    required XFile prescriptionImage,
    required String prescriptionPath,
  }) async {
    try {
      final bytes = await prescriptionImage.readAsBytes();
      final fileName = prescriptionImage.name;
      final storage = ref.read(storageServiceProvider);
      String jwtToken = storage.getFromSession('pg_admin');

      debugPrint('Uploading prescription directly to S3: $fileName');

      final filePart = MultipartFile.fromBytes(bytes, filename: fileName);
      FormData formData = FormData.fromMap({
        'upload_file': filePart,
        'key': prescriptionPath,
        'bucket_name': 'homecollection',
        'jwt_token': jwtToken,
      });

      Dio dio = Dio();
      Response response = await dio.post(
        '${Settings.nodeUrl}/s3/upload_file_v3',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status! < 600,
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('S3 upload failed: ${response.statusCode}');
      }

      debugPrint('Prescription uploaded successfully to S3: $prescriptionPath');
    } catch (e) {
      debugPrint('Failed to upload prescription to S3: $e');
      // Don't throw - allow work order creation to continue
    }
  }
}

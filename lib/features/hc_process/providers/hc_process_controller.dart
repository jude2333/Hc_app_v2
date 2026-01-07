import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart' show XFile, ImageSource;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/models/technician_process_doc.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/providers/notificationCenter_provider.dart';
import 'package:anderson_crm_flutter/providers/com_center_provider.dart';
import 'package:anderson_crm_flutter/repositories/temp_upload_repository.dart';
import 'package:anderson_crm_flutter/database/sms_template.dart';

import './hc_process_provider.dart';

class HCProcessController {
  final Ref _ref;
  final String workOrderId;

  HCProcessController(this._ref, this.workOrderId);

  HCProcessNotifier get _notifier =>
      _ref.read(hcProcessProvider(workOrderId).notifier);

  HCProcessState get _state => _ref.read(hcProcessProvider(workOrderId));

  Future<void> loadWorkOrder() async {
    _notifier.setLoading(true);

    try {
      final powerSync = _ref.read(powerSyncServiceProvider);
      final rowMap = await powerSync.getWorkOrderById(workOrderId);

      if (rowMap == null) {
        _notifier.setError('Work order not found');
        _notifier.setLoading(false);
        return;
      }

      final workOrder = WorkOrder.fromRow(rowMap);
      final processDoc = TechnicianProcessDoc.fromJson(workOrder.parsedDoc);

      final storage = _ref.read(storageServiceProvider);

      _notifier.setWorkOrderData(
        workOrder: workOrder,
        processDoc: processDoc,
        clientMobile: workOrder.mobile,
        techMobile: storage.getFromSession('logged_in_mobile') ?? '',
        b2bClient: (workOrder.b2bClientId ?? 0) > 0,
        b2bClientDetail: workOrder.b2bClientName,
        creditClient: workOrder.credit == 1,
        trialClient: workOrder.credit == 2,
        sms: workOrder.sendSms ? 1 : 0,
        whatsapp: workOrder.sendWhatsapp ? 1 : 0,
        email: workOrder.sendEmail ? 1 : 0,
      );

      if (processDoc.process.firstStep?.isNotEmpty == true) {
        _notifier.setDelayReason(processDoc.process.firstStep!);
      }

      if (processDoc.total != null) {
        _notifier.setBillAmount(processDoc.total!);
        calculateDiscount();
      }

      _beforeFirstStep();
    } catch (e) {
      debugPrint('Error loading work order: $e');
      _notifier.setError('Error loading work order: $e');
    } finally {
      _notifier.setLoading(false);
    }
  }

  Future<void> _updateWorkOrderViaPowerSync(
      TechnicianProcessDoc updatedProcessDoc) async {
    final powerSync = _ref.read(powerSyncServiceProvider);
    final storage = _ref.read(storageServiceProvider);

    final currentMap = await powerSync.getWorkOrderById(workOrderId);
    if (currentMap == null) throw Exception('Work order not found');

    final currentOrder = WorkOrder.fromRow(currentMap);
    final updatedDocMap = Map<String, dynamic>.from(currentOrder.parsedDoc);
    updatedDocMap.addAll(updatedProcessDoc.toJson());

    String docDbs = storage.getFromSession('doc_dbs') ?? '';
    if (docDbs.isNotEmpty) updatedDocMap['doc_dbs'] = docDbs;
    updatedDocMap['updated_at'] = DateTime.now().toIso8601String();

    double newBillAmount = updatedProcessDoc.total ?? currentOrder.billAmount;
    double newDiscount =
        updatedProcessDoc.discount ?? currentOrder.discountAmount;
    double newReceived = currentOrder.receivedAmount;
    if (updatedProcessDoc.amountReceived != null) {
      newReceived =
          double.tryParse(updatedProcessDoc.amountReceived.toString()) ?? 0.0;
    }

    final updatedOrder = currentOrder.copyWith(
      status: updatedProcessDoc.status ?? currentOrder.status,
      doc: jsonEncode(updatedDocMap),
      lastUpdatedBy: storage.getFromSession('logged_in_emp_name'),
      lastUpdatedAt: DateTime.now(),
      billAmount: newBillAmount,
      discountAmount: newDiscount,
      receivedAmount: newReceived,
    );

    final workOrdersProvider = _ref.read(workOrderProvider);
    await workOrdersProvider.updateWorkOrder(updatedOrder,
        customDoc: updatedDocMap);

    _notifier.updateProcessDoc(updatedProcessDoc);
    _notifier.updateWorkOrder(updatedOrder);
  }

  void _beforeFirstStep() {
    final resumeStep = _determineCurrentStep();
    if (resumeStep > 0) {
      _notifier.setCurrentStep(resumeStep);
      return;
    }

    final workOrder = _state.workOrder;
    if (workOrder != null) {
      String aptDate = workOrder.visitDate.toIso8601String().split('T')[0];
      String aptTime = workOrder.visitTime;

      if (aptTime.isNotEmpty) {
        try {
          final appointmentDateTime = DateTime.parse('$aptDate $aptTime');
          final now = DateTime.now();
          final difference = now.difference(appointmentDateTime);

          if (difference.inMinutes > -30) {
            _notifier.setDelayReason("On Time");
            afterFirstStep();
            return;
          }

          if (difference.inMinutes > 15) {
            _notifier.setDelayMins('${difference.inMinutes}');
          }
        } catch (e) {
          debugPrint('Date parse error: $e');
        }
      }
    }

    final processDoc = _state.processDoc;
    if (processDoc?.process.firstStep?.isNotEmpty == true) {
      _notifier.setDelayReason(processDoc!.process.firstStep!);
      _notifier.setCurrentStep(1);
    } else {
      _notifier.setCurrentStep(0);
    }
  }

  int _determineCurrentStep() {
    final processDoc = _state.processDoc;
    if (processDoc == null) return 0;
    final process = processDoc.process;

    if (processDoc.status == 'Finished') return 6;

    if (process.fifthStep?.isNotEmpty == true) {
      _notifier.setOfflineMode(false);
      final paths =
          process.fifthStep!.split(',').where((p) => p.isNotEmpty).toList();
      for (var path in paths) {
        _notifier.addUploadedPhoto(path.split('/').last, path);
      }
      return 5;
    }
    if (process.fourthStep?.isNotEmpty == true) return 4;
    if (process.thirdStep?.isNotEmpty == true) {
      _notifier.setDiscount(processDoc.discount ?? 0);
      _notifier.setHcCharges(processDoc.hcCharges ?? 50);
      _notifier.setDisposableCharges(processDoc.disposableCharges ?? 30);
      _notifier.setAmountReceived(
          double.tryParse(processDoc.amountReceived ?? '0') ?? 0);
      return 3;
    }
    if (process.secondStep?.isNotEmpty == true) {
      if (processDoc.testItems.isNotEmpty) {
        _notifier.setSelectedTests(
            processDoc.testItems.map((e) => e.toJson()).toList());
      }
      _notifier.setBillAmount(processDoc.total ?? 0);
      _notifier.setTotalAmount(processDoc.total ?? 0);
      _notifier.setProformaInvLoc(process.secondStep ?? '');
      return 2;
    }
    if (process.firstStep?.isNotEmpty == true) {
      _notifier.setDelayReason(process.firstStep!);
      return 1;
    }
    return 0;
  }

  Future<bool> afterFirstStep() async {
    if (_state.delayMins.isNotEmpty && _state.delayReason.length < 5) {
      return false;
    }

    final storage = _ref.read(storageServiceProvider);
    String timeline =
        '${Util.gettime()} - ${storage.getFromSession('logged_in_emp_name')} - Work Order Started';

    var processDoc = _state.processDoc!
        .updateProcessStep('first_step', _state.delayReason)
        .copyWith(status: 'First Step')
        .addTimelineEntry(timeline);

    await _updateWorkOrderViaPowerSync(processDoc);
    _notifier.setCurrentStep(1);
    return true;
  }

  Future<int> afterSecondStep() async {
    if (_state.selectedTests.isEmpty) {
      return -1;
    }

    _notifier.setLoading(true);

    try {
      final testItems =
          _state.selectedTests.map((test) => TestItem.fromJson(test)).toList();

      double total = _state.totalAmount > 0
          ? _state.totalAmount
          : testItems.fold(0.0, (sum, item) {
              double price = (_state.cghsPrice && (item.cghsPrice ?? 0) > 0)
                  ? item.cghsPrice!
                  : (item.baseCost ?? 0);
              return sum + price;
            });

      String proformaPath = _state.proformaInvLoc.isNotEmpty
          ? _state.proformaInvLoc
          : 'homecollection/proforma/${Util.getTodayStringForFolderCreation()}/proforma_${_state.clientMobile}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      var processDoc = _state.processDoc!
          .copyWith(testItems: testItems, total: total, status: 'Second Step')
          .updateProcessStep('second_step', proformaPath)
          .updateProcessStep('proforma_uploaded_at', 'NOT_CREATED');

      _notifier.setBillAmount(total);
      _notifier.setTotalAmount(total);
      calculateDiscount();

      await _updateWorkOrderViaPowerSync(processDoc);

      if (_state.b2bClient) {
        await _skipToFifthStep(
            'Not Received For B2B Client', 'OTP Not Needed For B2B Client');
        return 4;
      } else if (_state.trialClient) {
        await _skipToFifthStep(
            'Not Received For Trial Client', 'OTP Not Needed For Trial Client');
        return 4;
      } else if (_state.creditClient && !_state.cghsPrice) {
        await _skipToFifthStep('Not Received For Credit Client',
            'OTP Not Needed For Credit Client');
        return 4;
      }

      _notifier.setCurrentStep(2);
      return 2;
    } catch (e) {
      debugPrint('Error in afterSecondStep: $e');
      return -2;
    } finally {
      _notifier.setLoading(false);
    }
  }

  Future<void> _skipToFifthStep(String paymentNote, String otpNote) async {
    var processDoc = _state.processDoc!
        .copyWith(amountReceived: '0', discount: 0, status: 'Fifth Step')
        .updateProcessStep(
            'third_step', 'Rs. ${_state.billAmount} $paymentNote')
        .updateProcessStep('fourth_step', otpNote);

    await _updateWorkOrderViaPowerSync(processDoc);
    _notifier.setCurrentStep(4);
  }

  Future<void> afterThirdStep() async {
    if (_state.creditClient && _state.cghsPrice) {
      var processDoc = _state.processDoc!.copyWith(
        credit: 1,
        cghs: 1,
        amountReceived: _state.amountReceived.toString(),
        discount: 0,
        status: 'Fifth Step',
      );
      processDoc = processDoc
          .updateProcessStep('third_step',
              'Rs. ${_state.billAmount} Not Received For CGHS Credit Client. Only HC Charges Rs. ${_state.amountReceived} Received.')
          .updateProcessStep(
              'fourth_step', 'OTP Not Needed For CGHS Credit Client');

      await _updateWorkOrderViaPowerSync(processDoc);
      _notifier.setCurrentStep(4);
      return;
    }

    if (_state.creditClient) {
      var processDoc = _state.processDoc!.copyWith(
        credit: 1,
        amountReceived: '0',
        discount: 0,
        status: 'Fifth Step',
      );
      processDoc = processDoc
          .updateProcessStep('third_step',
              'Rs. ${_state.billAmount} Not Received For Credit Client')
          .updateProcessStep('fourth_step', 'OTP Not Needed For Credit Client');

      await _updateWorkOrderViaPowerSync(processDoc);
      _notifier.setCurrentStep(4);
      return;
    }

    String step3Summary =
        'Rs. ${_state.billAmount}. Received Rs. ${_state.amountReceived} with ${_state.discount}% discount.';

    var processDoc = _state.processDoc!.copyWith(
      discount: _state.discount,
      hcCharges: _state.hcCharges,
      disposableCharges: _state.disposableCharges,
      amountReceived: _state.amountReceived.toString(),
      total: _state.billAmount + _state.hcCharges + _state.disposableCharges,
      status: 'Third Step',
    );
    processDoc = processDoc.updateProcessStep('third_step', step3Summary);

    await _updateWorkOrderViaPowerSync(processDoc);

    if (_state.sms == 1 || _state.whatsapp == 1 || _state.email == 1) {
      await generateOtp();
      _notifier.setCurrentStep(3);
    } else {
      _notifier.setCurrentStep(4);
    }
  }

  void calculateDiscount() {
    try {
      double bill = _state.billAmount;
      double discountVal = _state.discount;
      double hcc = _state.hcCharges;
      double dis = _state.disposableCharges;

      double moneyAfterDiscount = bill;
      if (discountVal > 0) {
        moneyAfterDiscount = bill - (bill * discountVal / 100);
      }

      if (_state.creditClient) {
        if (_state.cghsPrice) {
          _notifier.updateBillingState(
            amountAfterDiscount: 0,
            amountReceived: (hcc + dis).roundToDouble(),
          );
        } else {
          _notifier.updateBillingState(
            amountAfterDiscount: 0,
            amountReceived: 0,
          );
        }
      } else {
        _notifier.updateBillingState(
          amountAfterDiscount: moneyAfterDiscount.roundToDouble(),
          amountReceived: (moneyAfterDiscount + hcc + dis).roundToDouble(),
        );
      }
    } catch (e) {
      debugPrint('Calc Error: $e');
    }
  }

  Future<void> generateOtp() async {
    _notifier.setLoading(true);

    try {
      final otp = Util.generateOTP();
      _notifier.setGeneratedOtp(otp);
      debugPrint('📱 Generated OTP: $otp');

      if (Settings.development) {
        debugPrint('🔧 Development mode: OTP will be shown in UI');
        _notifier.setLoading(false);
        return;
      }

      await _sendOtpMsg(otp);
    } catch (e) {
      debugPrint('❌ Error generating OTP: $e');
    } finally {
      _notifier.setLoading(false);
    }
  }

  bool verifyOtp(String enteredOtp) {
    if (enteredOtp.isEmpty) return false;

    if (enteredOtp == _state.generatedOtp) {
      var processDoc = _state.processDoc!
          .copyWith(status: 'Fourth Step')
          .updateProcessStep(
              'fourth_step', '${_state.generatedOtp} OTP matched');

      _updateWorkOrderViaPowerSync(processDoc);
      _notifier.setCurrentStep(4);
      return true;
    }

    if (_state.techMobile.length >= 6) {
      String last6 = _state.techMobile.substring(_state.techMobile.length - 6);
      if (enteredOtp == last6) {
        var processDoc = _state.processDoc!
            .copyWith(status: 'Fourth Step')
            .updateProcessStep(
                'fourth_step', '${_state.generatedOtp} Number matched');

        _updateWorkOrderViaPowerSync(processDoc);
        _notifier.setCurrentStep(4);
        return true;
      }
    }

    return false;
  }

  Future<void> _sendOtpMsg(String otp) async {
    try {
      final storage = _ref.read(storageServiceProvider);
      final comCenterService = _ref.read(comCenterServiceProvider);

      String idPart = Util.getRandomString(5);
      String msgUrl = '${Settings.msgUrl}$idPart';

      final baseMessage = {
        'center_id': storage.getFromSession('logged_in_tenant_id') ?? '',
        'center_name': storage.getFromSession('logged_in_tenant_name') ?? '',
        'department_id': storage.getFromSession('department_id') ?? '',
        'department_name': storage.getFromSession('department_name') ?? '',
        'role_id': storage.getFromSession('role_id') ?? '',
        'role_name': storage.getFromSession('role_name') ?? '',
        'emp_id': storage.getFromSession('logged_in_emp_id') ?? '',
        'emp_name': storage.getFromSession('logged_in_emp_name') ?? '',
        'recipient_mobile': _state.clientMobile,
        'recipient_name': _state.workOrder!.patientName,
        'status': '0',
        's3_loc': _state.proformaInvLoc,
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      if (_state.sms == 1) {
        final smsMsg = SmsTemplate.workOrderPatientOtp(otp, msgUrl);
        final smsMessage = {
          '_id': 'sms_center:$idPart:${Util.uuidv4()}',
          ...baseMessage,
          'message': smsMsg,
        };

        debugPrint(">>> SMS PAYLOAD: ${jsonEncode(smsMessage)}");
        await comCenterService.sendMessage(smsMessage);
      }

      if (_state.whatsapp == 1) {
        final whatsappMessage = {
          '_id': 'whatsapp_center:$idPart:${Util.uuidv4()}',
          ...baseMessage,
          'message': [msgUrl, otp],
          'template': 'hc_proforma_invoice',
        };

        debugPrint(">>> WHATSAPP PAYLOAD: ${jsonEncode(whatsappMessage)}");
        await comCenterService.sendMessage(whatsappMessage);
      }

      if (_state.email == 1) {
        final emailMessage = {
          '_id': 'email_center:$idPart:${Util.uuidv4()}',
          ...baseMessage,
        };

        debugPrint(">>> EMAIL PAYLOAD: ${jsonEncode(emailMessage)}");
        await comCenterService.sendMessage(emailMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending OTP: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<String?> uploadPrescription({
    required ImageSource source,
    Uint8List? webBytes,
    XFile? pickedFile,
  }) async {
    _notifier.setLoading(true);

    try {
      if (pickedFile == null) {
        _notifier.setLoading(false);
        return null;
      }

      final bytes = webBytes ?? await pickedFile.readAsBytes();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final fileLocation =
          'homecollection/prescriptions/${Util.getTodayStringForFolderCreation()}/$fileName';

      if (_state.offlineMode) {
        await _uploadOffline(pickedFile.name, fileLocation, bytes);
      } else {
        await _uploadToS3(fileLocation, bytes, fileName);
      }

      _notifier.addUploadedPhoto(pickedFile.name, fileLocation);

      var processDoc = _state.processDoc!
          .copyWith(status: 'Fifth Step')
          .updateProcessStep('fifth_step', _state.uploadedPhotoPaths.join(','))
          .updateProcessStep('prescription_uploaded_at',
              _state.offlineMode ? 'PENDING_OFFLINE' : Util.getTodayWithTime());

      await _updateWorkOrderViaPowerSync(processDoc);

      _notifier.setLoading(false);
      return fileLocation;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      _notifier.setLoading(false);
      rethrow;
    }
  }

  Future<void> _uploadOffline(
      String fileName, String fileLocation, Uint8List bytes) async {
    final storage = _ref.read(storageServiceProvider);
    final tenantId = int.tryParse(storage.getFromSession('tenant_id') ?? '');
    final createdBy =
        int.tryParse(storage.getFromSession('logged_in_emp_id') ?? '');

    final tempUploadRepo = _ref.read(tempUploadRepositoryProvider);
    await tempUploadRepo.saveOfflinePhoto(
      workOrderId: workOrderId,
      fileName: fileName,
      fileLocation: fileLocation,
      fileBytes: bytes,
      tenantId: tenantId,
      createdBy: createdBy,
    );
  }

  Future<void> _uploadToS3(
      String fileLocation, Uint8List bytes, String fileName) async {
    final storage = _ref.read(storageServiceProvider);
    String jwtToken = storage.getFromSession('pg_admin') ?? '';

    final filePart = MultipartFile.fromBytes(bytes, filename: fileName);
    FormData formData = FormData.fromMap({
      'upload_file': filePart,
      'key': fileLocation,
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
  }

  Future<bool> finishSteps(String mode) async {
    _notifier.setLoading(true);

    try {
      final storage = _ref.read(storageServiceProvider);
      String empName = storage.getFromSession('logged_in_emp_name') ?? '';
      String timeline = '${Util.gettime()} - $empName - Work Order Completed';

      String paymentMethod;
      String gpayRef = '';

      if (mode == 'credit') {
        paymentMethod = 'credit';
      } else if (mode == 'trial') {
        paymentMethod = 'trial';
      } else if (mode == 'b2b') {
        paymentMethod = 'b2b';
      } else {
        paymentMethod = _state.paymentMethod;
        gpayRef = _state.paymentMethod == 'gpay' ? _state.gpayRef : '';
      }

      var processDoc = _state.processDoc!.copyWith(
        status: 'Finished',
        serverStatus: 'Not Received',
        paymentMethod: paymentMethod,
        gpayRef: gpayRef,
        remarks: _state.remarks,
      );
      processDoc = processDoc
          .updateProcessStep('fifth_step', _state.uploadedPhotoPaths.join(','))
          .addTimelineEntry(timeline);

      try {
        await _updateWorkOrderViaPowerSync(processDoc);
      } catch (e) {
        if (!e.toString().contains("LegacyJavaScriptObject")) {
          rethrow;
        }
      }

      await _sendNotification();
      await _checkSugarTests();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_tests');

      _notifier.setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error finishing: $e');
      _notifier.setLoading(false);
      return false;
    }
  }

  Future<void> _sendNotification() async {
    try {
      final workOrder = _state.workOrder;
      if (workOrder == null) return;

      if (Settings.development) {
        debugPrint('🔧 Dev mode: Notification skipped');
        return;
      }

      final notificationService = _ref.read(notificationCenterServiceProvider);
      final appointmentDate =
          DateFormat('dd-MM-yyyy').format(workOrder.visitDate);

      await notificationService.sendWorkOrderCompleted(
        appointmentDate: appointmentDate,
        appointmentTime: workOrder.visitTime,
        patientName: workOrder.patientName,
        age: workOrder.age,
        gender: workOrder.gender,
        address: workOrder.address,
        mobile: workOrder.mobile,
        pincode: workOrder.pincode,
        freeText: workOrder.freeText,
        managerId: workOrder.managerId?.toString() ?? '',
        managerName: workOrder.managerName,
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> _checkSugarTests() async {
    final processDoc = _state.processDoc;
    if (processDoc == null) return;

    final hasSugar = processDoc.testItems.any((test) =>
        (test.investId == 177) ||
        (test.investName?.toLowerCase().contains('glucose') == true) ||
        (test.investName?.toLowerCase().contains('sugar') == true));

    if (hasSugar) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sugar_test_doc_id', workOrderId);
    }
  }
}

final hcProcessControllerProvider = Provider.autoDispose
    .family<HCProcessController, String>((ref, workOrderId) {
  return HCProcessController(ref, workOrderId);
});

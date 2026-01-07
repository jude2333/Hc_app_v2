import 'dart:convert';
import 'dart:io';
import 'package:anderson_crm_flutter/providers/notificationCenter_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/models/technician_process_doc.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/features/price_list/screens/add_test_dialog.dart';
import 'package:anderson_crm_flutter/services/com_center_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/database/sms_template.dart';
import 'package:anderson_crm_flutter/repositories/temp_upload_repository.dart';

import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/providers/com_center_provider.dart';

class HCProcessPage3 extends ConsumerStatefulWidget {
  final String workOrderId;

  const HCProcessPage3({
    Key? key,
    required this.workOrderId,
  }) : super(key: key);

  @override
  ConsumerState<HCProcessPage3> createState() => _HCProcessPageState();
}

class _HCProcessPageState extends ConsumerState<HCProcessPage3> {
  int _currentStep = 0;
  bool _isLoading = false;

  WorkOrder? _workOrder;
  TechnicianProcessDoc? _processDoc;

  final _delayTextController = TextEditingController();
  String _delayMins = '';

  bool _cghsPrice = false;
  String _proformaInvLoc = '';

  final _discountController = TextEditingController(text: '0');
  String _hccItem = '50';
  String _disCharges = '30';
  double _billAmount = 0;
  double _amountAfterDiscount = 0;
  double _amountReceived = 0;
  bool _creditClient = false;
  bool _trialClient = false;

  final _otpController = TextEditingController();
  String _generatedOtp = '';
  String _clientMobile = '';
  String _techMobile = '';

  final _imagePicker = ImagePicker();
  List<String> _uploadedPhotos = [];
  List<String> _uploadedPhotosPath = [];
  bool _offlineMode = false; // Toggle for offline photo upload

  String _paymentMethod = 'cash';
  final _gpayRefController = TextEditingController(text: 'Later');
  final _remarksController = TextEditingController();

  bool _b2bClient = false;
  String _b2bClientDetail = '';
  int _sms = 0;
  int _whatsapp = 0;
  int _email = 0;

  List<Map<String, dynamic>> _selectedTests = [];
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadWorkOrder();
  }

  @override
  void dispose() {
    _delayTextController.dispose();
    _discountController.dispose();
    _otpController.dispose();
    _gpayRefController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkOrder() async {
    setState(() => _isLoading = true);

    try {
      final powerSync = ref.read(powerSyncServiceProvider);

      final rowMap = await powerSync.getWorkOrderById(widget.workOrderId);

      if (rowMap == null) {
        _showSnackBar('Work order not found');
        setState(() => _isLoading = false);
        return;
      }

      final workOrder = WorkOrder.fromRow(rowMap);

      final processDoc = TechnicianProcessDoc.fromJson(workOrder.parsedDoc);

      setState(() {
        _workOrder = workOrder;
        _processDoc = processDoc;
        _clientMobile = workOrder.mobile;

        final storage = ref.read(storageServiceProvider);
        _techMobile = storage.getFromSession('logged_in_mobile') ?? '';

        if ((workOrder.b2bClientId ?? 0) > 0) {
          _b2bClient = true;
          _b2bClientDetail = workOrder.b2bClientName;
        }

        if (workOrder.credit == 1) {
          _creditClient = true;
          _trialClient = false;
        } else if (workOrder.credit == 2) {
          _creditClient = false;
          _trialClient = true;
        }

        if (processDoc.total != null) {
          _billAmount = processDoc.total!;
          _calculateDiscount();
        }

        _sms = workOrder.sendSms ? 1 : 0;
        _whatsapp = workOrder.sendWhatsapp ? 1 : 0;
        _email = workOrder.sendEmail ? 1 : 0;

        if (processDoc.process.firstStep?.isNotEmpty == true) {
          _delayTextController.text = processDoc.process.firstStep!;
        }
      });

      _beforeFirstStep();
    } catch (e) {
      debugPrint('Error loading work order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateWorkOrderViaPowerSync({
    required TechnicianProcessDoc updatedProcessDoc,
  }) async {
    try {
      final powerSync = ref.read(powerSyncServiceProvider);
      final storage = ref.read(storageServiceProvider);

      final currentMap = await powerSync.getWorkOrderById(widget.workOrderId);
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
        lastUpdatedBy:
            storage.getFromSession('logged_in_emp_name') ?? 'Technician',
        lastUpdatedAt: DateTime.now(),
        billAmount: newBillAmount,
        discountAmount: newDiscount,
        receivedAmount: newReceived,
      );

      final workOrdersProvider = ref.read(workOrderProvider);
      await workOrdersProvider.updateWorkOrder(updatedOrder,
          customDoc: updatedDocMap);

      setState(() {
        _processDoc = updatedProcessDoc;
        _workOrder = updatedOrder;
      });
    } catch (e) {
      debugPrint('Update Error: $e');
      rethrow;
    }
  }

  void _beforeFirstStep() {
    int resumeStep = _determineCurrentStep();
    if (resumeStep > 0) {
      setState(() => _currentStep = resumeStep);
      return;
    }

    if (_workOrder != null) {
      String aptDate = _workOrder!.visitDate.toIso8601String().split('T')[0];
      String aptTime = _workOrder!.visitTime;

      if (aptTime.isNotEmpty) {
        try {
          final appointmentDateTime = DateTime.parse('$aptDate $aptTime');
          final now = DateTime.now();
          final difference = now.difference(appointmentDateTime);

          if (difference.inMinutes > -30) {
            _delayTextController.text = "On Time";
            _afterFirstStep();
            return;
          }

          if (difference.inMinutes > 15) {
            _delayMins = '${difference.inMinutes}';
          }
        } catch (e) {
          debugPrint('Date parse error: $e');
        }
      }
    }

    if (_processDoc?.process.firstStep?.isNotEmpty == true) {
      _delayTextController.text = _processDoc!.process.firstStep!;
      setState(() => _currentStep = 1);
    } else {
      setState(() => _currentStep = 0);
    }
  }

  int _determineCurrentStep() {
    if (_processDoc == null) return 0;
    final process = _processDoc!.process;

    if (_processDoc!.status == 'Finished') return 6;

    if (process.fifthStep?.isNotEmpty == true) {
      _uploadedPhotosPath =
          process.fifthStep!.split(',').where((p) => p.isNotEmpty).toList();
      _uploadedPhotos =
          _uploadedPhotosPath.map((p) => p.split('/').last).toList();
      return 5;
    }
    if (process.fourthStep?.isNotEmpty == true) return 4;
    if (process.thirdStep?.isNotEmpty == true) {
      _discountController.text = (_processDoc!.discount ?? 0).toString();
      _hccItem = (_processDoc!.hcCharges ?? 50).toString();
      _disCharges = (_processDoc!.disposableCharges ?? 30).toString();
      _amountReceived =
          double.tryParse(_processDoc!.amountReceived ?? '0') ?? 0;
      return 3;
    }
    if (process.secondStep?.isNotEmpty == true) {
      if (_processDoc!.testItems.isNotEmpty) {
        _selectedTests = _processDoc!.testItems.map((e) => e.toJson()).toList();
      }
      _billAmount = _processDoc!.total ?? 0;
      _totalAmount = _billAmount;
      _proformaInvLoc = process.secondStep ?? '';
      return 2;
    }
    if (process.firstStep?.isNotEmpty == true) {
      _delayTextController.text = process.firstStep!;
      return 1;
    }
    return 0;
  }

  void _afterFirstStep() {
    if (_delayMins.isNotEmpty && _delayTextController.text.length < 5) {
      _showSnackBar('Please give proper reason for delay');
      return;
    }
    final storage = ref.read(storageServiceProvider);
    String timeline =
        '${Util.gettime()} - ${storage.getFromSession('logged_in_emp_name')} - Work Order Started';

    _processDoc = _processDoc!
        .updateProcessStep('first_step', _delayTextController.text)
        .copyWith(status: 'First Step')
        .addTimelineEntry(timeline);

    _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
    setState(() => _currentStep = 1);
  }

  Future<void> _afterSecondStep() async {
    if (_selectedTests.isEmpty) {
      _showSnackBar('Please add at least one test');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final testItems =
          _selectedTests.map((test) => TestItem.fromJson(test)).toList();

      double total;
      if (_totalAmount > 0) {
        total = _totalAmount;
      } else {
        total = testItems.fold(0.0, (sum, item) {
          double price = (_cghsPrice && (item.cghsPrice ?? 0) > 0)
              ? item.cghsPrice!
              : (item.baseCost ?? 0);
          return sum + price;
        });
      }

      String proformaPath = _proformaInvLoc.isNotEmpty
          ? _proformaInvLoc
          : 'homecollection/proforma/${Util.getTodayStringForFolderCreation()}/proforma_${_clientMobile}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      _processDoc = _processDoc!
          .copyWith(testItems: testItems, total: total, status: 'Second Step')
          .updateProcessStep('second_step', proformaPath)
          .updateProcessStep('proforma_uploaded_at', 'NOT_CREATED');

      setState(() {
        _billAmount = total;
        _totalAmount = total;
        _calculateDiscount();
      });

      await _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);

      if (_b2bClient) {
        _skipToFifthStep(
            'Not Received For B2B Client', 'OTP Not Needed For B2B Client');
      } else if (_trialClient) {
        _skipToFifthStep(
            'Not Received For Trial Client', 'OTP Not Needed For Trial Client');
      } else if (_creditClient) {
        if (_cghsPrice) {
          setState(() {
            _currentStep = 2;
            _isLoading = false;
          });
        } else {
          _skipToFifthStep('Not Received For Credit Client',
              'OTP Not Needed For Credit Client');
        }
      } else {
        setState(() {
          _currentStep = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _skipToFifthStep(String paymentNote, String otpNote) {
    _processDoc = _processDoc!
        .copyWith(amountReceived: '0', discount: 0, status: 'Fifth Step')
        .updateProcessStep('third_step', 'Rs. $_billAmount $paymentNote')
        .updateProcessStep('fourth_step', otpNote);

    _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
    setState(() {
      _currentStep = 4;
      _isLoading = false;
    });
  }

  void _afterThirdStep() {
    if (_creditClient && _cghsPrice) {
      _processDoc = _processDoc!
          .copyWith(
              credit: 1,
              cghs: 1,
              amountReceived: _amountReceived.toString(),
              discount: 0,
              status: 'Fifth Step')
          .updateProcessStep('third_step',
              'Rs. $_billAmount Not Received For CGHS Credit Client. Only HC Charges Rs. $_amountReceived Received For CGHS Credit Client.')
          .updateProcessStep(
              'fourth_step', 'OTP Not Needed For CGHS Credit Client');

      _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
      setState(() => _currentStep = 4);
      return;
    }

    if (_creditClient) {
      _processDoc = _processDoc!
          .copyWith(
              credit: 1, amountReceived: '0', discount: 0, status: 'Fifth Step')
          .updateProcessStep(
              'third_step', 'Rs. $_billAmount Not Received For Credit Client')
          .updateProcessStep('fourth_step', 'OTP Not Needed For Credit Client');

      _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
      setState(() => _currentStep = 4);
      return;
    }

    if (_discountController.text.isEmpty) {
      _showSnackBar('Please enter discount amount');
      return;
    }

    final step3Summary =
        'Rs. $_billAmount. Received Rs. $_amountReceived with ${_discountController.text}% discount.';

    _processDoc = _processDoc!
        .copyWith(
          discount: double.parse(_discountController.text),
          hcCharges: double.parse(_hccItem),
          disposableCharges: double.parse(_disCharges),
          amountReceived: _amountReceived.toString(),
          total:
              _billAmount + double.parse(_hccItem) + double.parse(_disCharges),
          status: 'Third Step',
        )
        .updateProcessStep('third_step', step3Summary);

    _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);

    if (_sms == 1 || _whatsapp == 1 || _email == 1) {
      _generateOtp();
      setState(() => _currentStep = 3);
    } else {
      debugPrint('⚠️ No communication method enabled, skipping OTP');
      setState(() => _currentStep = 4);
    }
  }

  Future<void> _generateOtp() async {
    try {
      setState(() => _isLoading = true);

      _generatedOtp = Util.generateOTP();
      debugPrint('📱 Generated OTP: $_generatedOtp');

      if (Settings.development) {
        debugPrint('🔧 Development mode: OTP will be shown in UI');
        _showSnackBar('Dev Mode: OTP = $_generatedOtp');
        setState(() => _isLoading = false);
        return;
      }

      await _sendOtpMsg();
      _showSnackBar('OTP sent successfully!');

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error generating OTP: $e');
      _showSnackBar('Error generating OTP: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateDiscount() {
    try {
      double bill = _billAmount;
      double discountVal = 0;

      if (_discountController.text.isNotEmpty) {
        discountVal = double.tryParse(_discountController.text) ?? 0;
      }

      double hcc = double.tryParse(_hccItem) ?? 0;
      double dis = double.tryParse(_disCharges) ?? 0;

      double moneyAfterDiscount = bill;
      if (discountVal > 0) {
        moneyAfterDiscount = bill - (bill * discountVal / 100);
      }

      if (_creditClient) {
        if (_cghsPrice) {
          setState(() {
            _amountAfterDiscount = 0;
            _amountReceived = (hcc + dis).roundToDouble();
          });
        } else {
          setState(() {
            _amountAfterDiscount = 0;
            _amountReceived = 0;
          });
        }
      } else {
        setState(() {
          _amountAfterDiscount = moneyAfterDiscount.roundToDouble();
          _amountReceived = (moneyAfterDiscount + hcc + dis).roundToDouble();
        });
      }
    } catch (e) {
      debugPrint('Calc Error: $e');
    }
  }

  Future<void> _sendOtp() async {
    try {
      setState(() => _isLoading = true);
      _generatedOtp = Util.generateOTP();
      debugPrint('Generated OTP: $_generatedOtp');
      _showSnackBar('OTP Generated: $_generatedOtp (Check console)');
      setState(() => _isLoading = false);
    } catch (e) {
      _showSnackBar('Error generating OTP: $e');
      setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() {
    if (_otpController.text.isEmpty) {
      _showSnackBar('Please enter OTP');
      return;
    }
    if (_otpController.text == _generatedOtp) {
      _processDoc = _processDoc!
          .copyWith(status: 'Fourth Step')
          .updateProcessStep('fourth_step', '$_generatedOtp OTP matched');

      _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
      setState(() => _currentStep = 4);
      _showSnackBar('OTP Verified');
      return;
    }

    if (_techMobile.length >= 6) {
      String last6 = _techMobile.substring(_techMobile.length - 6);
      if (_otpController.text == last6) {
        _processDoc = _processDoc!
            .copyWith(status: 'Fourth Step')
            .updateProcessStep('fourth_step', '$_generatedOtp Number matched');

        _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
        setState(() => _currentStep = 4);
        _showSnackBar('Number matched');
        return;
      }
    }
    _showSnackBar('Invalid OTP');
  }

  Future<void> _uploadPrescription() async {
    try {
      ImageSource? source;
      if (!kIsWeb) {
        source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera)),
                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery)),
              ],
            ),
          ),
        );
        if (source == null) return;
      }

      setState(() => _isLoading = true);
      XFile? pickedFile;
      Uint8List? fileBytes;

      if (kIsWeb) {
        final result =
            await FilePicker.platform.pickFiles(type: FileType.image);
        if (result == null) {
          setState(() => _isLoading = false);
          return;
        }
        fileBytes = result.files.single.bytes;
        pickedFile = XFile.fromData(fileBytes!, name: result.files.single.name);
      } else {
        pickedFile =
            await _imagePicker.pickImage(source: source!, imageQuality: 85);
      }

      if (pickedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      final uploadedPath = await _uploadToS3(pickedFile, webBytes: fileBytes);
      _uploadedPhotosPath.add(uploadedPath);
      _uploadedPhotos.add(pickedFile.name);

      _processDoc = _processDoc!
          .copyWith(status: 'Fifth Step')
          .updateProcessStep('fifth_step', _uploadedPhotosPath.join(','))
          .updateProcessStep(
              'prescription_uploaded_at', Util.getTodayWithTime());

      await _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);

      setState(() => _isLoading = false);
      _showSnackBar('Prescription uploaded successfully');
    } catch (e, st) {
      debugPrint('❌ Error: $e\n$st');
      _showSnackBar('Error uploading: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<String> _uploadToS3(XFile image, {Uint8List? webBytes}) async {
    final storage = ref.read(storageServiceProvider);
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
    String fileLocation =
        'homecollection/prescriptions/${Util.getTodayStringForFolderCreation()}/$fileName';
    String jwtToken = storage.getFromSession('pg_admin') ?? '';

    final MultipartFile filePart;
    if (kIsWeb && webBytes != null) {
      filePart = MultipartFile.fromBytes(webBytes, filename: fileName);
    } else {
      filePart = await MultipartFile.fromFile(image.path, filename: fileName);
    }

    FormData formData = FormData.fromMap({
      'upload_file': filePart,
      'key': fileLocation,
      'bucket_name': 'homecollection',
      'jwt_token': jwtToken,
    });

    Dio dio = Dio();
    try {
      Response response = await dio.post(
          '${Settings.nodeUrl}/s3/upload_file_v3',
          data: formData,
          options: Options(
              headers: {'Content-Type': 'multipart/form-data'},
              validateStatus: (status) => status! < 600));
      if (response.statusCode == 200)
        return fileLocation;
      else
        throw Exception('S3 upload failed: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Upload prescription photo for offline sync via PowerSync
  Future<void> _uploadPrescriptionOffline() async {
    try {
      ImageSource? source;
      if (!kIsWeb) {
        source = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera)),
                ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery)),
              ],
            ),
          ),
        );
        if (source == null) return;
      }

      setState(() => _isLoading = true);
      XFile? pickedFile;
      Uint8List? fileBytes;

      if (kIsWeb) {
        final result =
            await FilePicker.platform.pickFiles(type: FileType.image);
        if (result == null) {
          setState(() => _isLoading = false);
          return;
        }
        fileBytes = result.files.single.bytes;
        pickedFile = XFile.fromData(fileBytes!, name: result.files.single.name);
      } else {
        pickedFile =
            await _imagePicker.pickImage(source: source!, imageQuality: 85);
      }

      if (pickedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Read file bytes
      final bytes = fileBytes ?? await pickedFile.readAsBytes();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      final fileLocation =
          'homecollection/prescriptions/${Util.getTodayStringForFolderCreation()}/$fileName';

      // Get storage for tenant/user info
      final storage = ref.read(storageServiceProvider);
      final tenantId = int.tryParse(storage.getFromSession('tenant_id') ?? '');
      final createdBy =
          int.tryParse(storage.getFromSession('logged_in_emp_id') ?? '');

      // Save to PowerSync temp_uploads table
      final tempUploadRepo = ref.read(tempUploadRepositoryProvider);
      await tempUploadRepo.saveOfflinePhoto(
        workOrderId: widget.workOrderId,
        fileName: fileName,
        fileLocation: fileLocation,
        fileBytes: bytes,
        tenantId: tenantId,
        createdBy: createdBy,
      );

      // Update state
      _uploadedPhotosPath.add(fileLocation);
      _uploadedPhotos.add(pickedFile.name);

      // Update process doc with pending upload status
      _processDoc = _processDoc!
          .copyWith(status: 'Fifth Step')
          .updateProcessStep('fifth_step', _uploadedPhotosPath.join(','))
          .updateProcessStep('prescription_uploaded_at', 'PENDING_OFFLINE');

      await _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);

      setState(() => _isLoading = false);
      _showSnackBar('Photo saved offline successfully! Will sync when online.');
    } catch (e, st) {
      debugPrint('❌ Offline upload error: $e\n$st');
      _showSnackBar('Error saving offline: $e');
      setState(() => _isLoading = false);
    }
  }

  void _afterFifthStep() {
    if (_uploadedPhotosPath.isEmpty) {
      _showSnackBar('Please upload at least one prescription photo');
      return;
    }
    setState(() => _currentStep = 5);
  }

  Future<void> _finishSteps(String mode) async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      String empName = storage.getFromSession('logged_in_emp_name') ?? '';
      String timeline = '${Util.gettime()} - $empName - Work Order Completed';

      String paymentMethod;
      String gpayRef = '';

      if (mode == 'credit')
        paymentMethod = 'credit';
      else if (mode == 'trial')
        paymentMethod = 'trial';
      else if (mode == 'b2b')
        paymentMethod = 'b2b';
      else {
        paymentMethod = _paymentMethod;
        gpayRef = _paymentMethod == 'gpay' ? _gpayRefController.text : '';
      }

      _processDoc = _processDoc!
          .copyWith(
            status: 'Finished',
            serverStatus: 'Not Received',
            paymentMethod: paymentMethod,
            gpayRef: gpayRef,
            remarks: _remarksController.text,
          )
          .updateProcessStep('fifth_step', _uploadedPhotosPath.join(','))
          .addTimelineEntry(timeline);

      try {
        await _updateWorkOrderViaPowerSync(updatedProcessDoc: _processDoc!);
      } catch (e) {
        if (e.toString().contains("LegacyJavaScriptObject")) {
          debugPrint("⚠️ PowerSync Web Sync Warning (Ignored): $e");
        } else {
          rethrow;
        }
      }

      _sendNotification();
      _checkSugarTests();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_tests');

      if (mounted) {
        _showSnackBar('Work Order Completed Successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      debugPrint('Error: $e\n$st');
      if (mounted) _showSnackBar('Error completing work order: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkSugarTests() async {
    final hasSugarId = _processDoc!.testItems
        .any((test) => (test.investId != null && test.investId == 177));

    final hasSugarName = _processDoc!.testItems.any((test) =>
        test.investName?.toLowerCase().contains('glucose') == true ||
        test.investName?.toLowerCase().contains('sugar') == true);

    if (hasSugarId || hasSugarName) {
      debugPrint('🍬 Sugar tests detected');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sugar_test_doc_id', widget.workOrderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HC Process'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_workOrder == null || _processDoc == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HC Process'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: Text('Loading work order...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('HC Process - ${_workOrder!.patientName}'),
        backgroundColor: Colors.orange,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              children: [
                if (details.stepIndex < 5)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue'),
                  ),
                const SizedBox(width: 12),
                if (details.stepIndex > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back',
                        style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Step 1: Delay Reason'),
            content: _buildStep1(),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Step 2: Add Tests'),
            content: _buildStep2(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Step 3: Calculate Bill'),
            content: _buildStep3(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Step 4: OTP Verification'),
            content: _buildStep4(),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Step 5: Upload Prescription'),
            content: _buildStep5(),
            isActive: _currentStep >= 4,
            state: _currentStep > 4 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Step 6: Payment & Finish'),
            content: _buildStep6(),
            isActive: _currentStep >= 5,
            state: _currentStep == 5 ? StepState.indexed : StepState.complete,
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_delayMins.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('Delayed by $_delayMins minutes',
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold))),
      TextField(
          controller: _delayTextController,
          decoration: const InputDecoration(
              labelText: 'Delay Reason',
              hintText: 'Enter reason',
              border: OutlineInputBorder()),
          maxLines: 3),
      const SizedBox(height: 16),
      Text('Patient: ${_workOrder!.patientName}',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      Text('Mobile: $_clientMobile'),
      Text('Appointment: ${_workOrder!.visitTime}'),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ElevatedButton.icon(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AddTestDialog(
                  workOrder: _workOrder!.toMap(), useCghsPrice: _cghsPrice),
            );
            if (result != null && result is Map<String, dynamic>) {
              setState(() {
                if (result['testitems'] != null)
                  _selectedTests =
                      List<Map<String, dynamic>>.from(result['testitems']);
                if (result['total'] != null) {
                  _totalAmount = (result['total'] as num).toDouble();
                  _billAmount = _totalAmount;
                }
                if (result['proformalocation'] != null)
                  _proformaInvLoc = result['proformalocation'].toString();
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedTests.isNotEmpty) _afterSecondStep();
              });
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Tests'),
        ),
        const SizedBox(width: 8),
        if (!_trialClient) ...[
          Checkbox(
              value: _cghsPrice,
              onChanged: (v) => setState(() => _cghsPrice = v ?? false)),
          const Text('Use CGHS Price'),
        ]
      ]),
      const SizedBox(height: 16),
      if (_selectedTests.isNotEmpty) ...[
        const Text('Selected Tests:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ..._selectedTests.map((test) => ListTile(
            title: Text(test['invest_name'] ?? 'Unknown'),
            trailing: Text('₹${test['base_cost'] ?? '0'}'))),
        const Divider(),
        Text('Total: ₹$_totalAmount',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    ]);
  }

  bool get _areChargesEnabled {
    if (_creditClient) {
      return _cghsPrice;
    }
    return true;
  }

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bill Amount: ₹${Util.formatMoney(_billAmount)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('Credit Client?'),
        value: _creditClient,
        activeColor: Colors.orange,
        contentPadding: EdgeInsets.zero,
        onChanged: (val) {
          setState(() {
            _creditClient = val;
            if (_creditClient) {
              _discountController.text = "0";
              _hccItem = "50";
              _disCharges = "30";
            }
            _calculateDiscount();
          });
        },
      ),
      const Divider(),
      TextField(
          controller: _discountController,
          decoration: const InputDecoration(
              labelText: 'Discount %',
              border: OutlineInputBorder(),
              suffixText: '%'),
          keyboardType: TextInputType.number,
          enabled: !_creditClient,
          onChanged: (_) => _calculateDiscount()),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: DropdownButtonFormField<String>(
          value: _hccItem,
          decoration: const InputDecoration(
            labelText: 'HC Charges',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: ['0', '25', '50', '100', '150', '200', '250']
              .map((val) => DropdownMenuItem(value: val, child: Text(val)))
              .toList(),
          onChanged: _areChargesEnabled
              ? (v) {
                  setState(() {
                    _hccItem = v!;
                    _calculateDiscount();
                  });
                }
              : null,
          style:
              TextStyle(color: _areChargesEnabled ? Colors.black : Colors.grey),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: DropdownButtonFormField<String>(
          value: _disCharges,
          decoration: const InputDecoration(
            labelText: 'Disp. Charges',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: ['0', '10', '20', '30', '40', '50', '100']
              .map((val) => DropdownMenuItem(value: val, child: Text(val)))
              .toList(),
          onChanged: _areChargesEnabled
              ? (v) {
                  setState(() {
                    _disCharges = v!;
                    _calculateDiscount();
                  });
                }
              : null,
          style:
              TextStyle(color: _areChargesEnabled ? Colors.black : Colors.grey),
        )),
      ]),
      const SizedBox(height: 16),
      Card(
          color: Colors.grey.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('After Discount:'),
                        Text('₹$_amountAfterDiscount',
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount to Receive:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('₹$_amountReceived',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ]))),
      if (_b2bClient)
        Chip(
            label: Text('B2B Client: $_b2bClientDetail'),
            backgroundColor: Colors.blue.shade100),
      if (_creditClient)
        const Chip(
            label: Text('Credit Client'), backgroundColor: Colors.orangeAccent),
      if (_trialClient)
        const Chip(label: Text('Trial Client'), backgroundColor: Colors.purple),
    ]);
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OTP Verification',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (Settings.development)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber[100],
              border: Border.all(color: Colors.amber[700]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.developer_mode, color: Colors.amber[900]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Development Mode: OTP displayed below',
                    style: TextStyle(
                      color: Colors.amber[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton.icon(
          onPressed: _generateOtp,
          icon: const Icon(Icons.send),
          label: Text(Settings.development
              ? 'Generate OTP (Dev Mode)'
              : 'Send OTP to Customer'),
        ),
        const SizedBox(height: 16),
        if (_generatedOtp.isNotEmpty) ...[
          if (Settings.development)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Generated OTP',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _generatedOtp,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OTP sent via ${_getEnabledMethods()}',
                      style: TextStyle(
                        color: Colors.green[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            decoration: const InputDecoration(
              labelText: 'Enter OTP',
              border: OutlineInputBorder(),
              hintText: 'Enter 6-digit OTP',
              prefixIcon: Icon(Icons.lock),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Verify OTP'),
          ),
        ],
      ],
    );
  }

  String _getEnabledMethods() {
    List<String> methods = [];
    if (_sms == 1) methods.add('SMS');
    if (_whatsapp == 1) methods.add('WhatsApp');
    if (_email == 1) methods.add('Email');
    return methods.isEmpty ? 'None' : methods.join(', ');
  }

  Widget _buildStep5() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Upload Prescription Photos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),

      // Offline mode toggle
      SwitchListTile(
        title: const Text('Offline Mode'),
        subtitle: Text(_offlineMode
            ? 'Photos saved locally, sync when online'
            : 'Upload directly to server'),
        value: _offlineMode,
        activeColor: Colors.orange,
        onChanged: (value) {
          setState(() {
            _offlineMode = value;
            // Clear uploaded photos when switching modes
            _uploadedPhotos.clear();
            _uploadedPhotosPath.clear();
          });
        },
      ),
      const SizedBox(height: 12),

      // Status indicator for offline mode
      if (_offlineMode)
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Photos will be saved offline and uploaded automatically when network is available.',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

      ElevatedButton.icon(
          onPressed: _isLoading
              ? null
              : (_offlineMode
                  ? _uploadPrescriptionOffline
                  : _uploadPrescription),
          style: ElevatedButton.styleFrom(
            backgroundColor: _offlineMode ? Colors.orange : Colors.blue,
          ),
          icon: Icon(_offlineMode ? Icons.save : Icons.cloud_upload),
          label: Text(_isLoading
              ? 'Processing...'
              : (_offlineMode ? 'Save Photo Offline' : 'Upload Photo'))),
      const SizedBox(height: 16),
      if (_uploadedPhotosPath.isNotEmpty) ...[
        Text('${_offlineMode ? "Saved" : "Uploaded"} Photos:',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _uploadedPhotos.asMap().entries.map((e) {
              return Chip(
                avatar: Icon(
                  _offlineMode ? Icons.cloud_off : Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
                backgroundColor: _offlineMode ? Colors.orange : Colors.green,
                label: Text('Photo ${e.key + 1}: ${e.value}'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _uploadedPhotos.removeAt(e.key);
                    _uploadedPhotosPath.removeAt(e.key);
                  });
                },
              );
            }).toList()),
      ],
    ]);
  }

  Widget _buildStep6() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Payment & Finish',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Payment Method:'),
      RadioListTile(
          title: const Text('Cash'),
          value: 'cash',
          groupValue: _paymentMethod,
          onChanged: (v) => setState(() => _paymentMethod = v.toString())),
      RadioListTile(
          title: const Text('GPay/UPI'),
          value: 'gpay',
          groupValue: _paymentMethod,
          onChanged: (v) => setState(() => _paymentMethod = v.toString())),
      RadioListTile(
          title: const Text('Card'),
          value: 'card',
          groupValue: _paymentMethod,
          onChanged: (v) => setState(() => _paymentMethod = v.toString())),
      if (_paymentMethod == 'gpay')
        TextField(
            controller: _gpayRefController,
            decoration: const InputDecoration(
                labelText: 'GPay Reference Number',
                border: OutlineInputBorder())),
      const SizedBox(height: 16),
      TextField(
          controller: _remarksController,
          decoration: const InputDecoration(
              labelText: 'Remarks (Optional)', border: OutlineInputBorder()),
          maxLines: 3),
      const SizedBox(height: 24),
      const Text('Choose Finish Mode:',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ElevatedButton(
            onPressed: () => _finishSteps('normal'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Normal')),
        if (_creditClient)
          ElevatedButton(
              onPressed: () => _finishSteps('credit'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Credit')),
        if (_trialClient)
          ElevatedButton(
              onPressed: () => _finishSteps('trial'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Trial')),
        if (_b2bClient)
          ElevatedButton(
              onPressed: () => _finishSteps('b2b'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('B2B')),
      ]),
    ]);
  }

  Future<void> _sendOtpMsg() async {
    try {
      final storage = ref.read(storageServiceProvider);
      final comCenterService = ref.read(comCenterServiceProvider);

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
        'recipient_mobile': _clientMobile,
        'recipient_name': _workOrder!.patientName,
        'status': '0',
        's3_loc': _proformaInvLoc,
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      if (_sms == 1) {
        final smsMsg = SmsTemplate.workOrderPatientOtp(_generatedOtp, msgUrl);
        final smsMessage = {
          '_id': 'sms_center:$idPart:${Util.uuidv4()}',
          ...baseMessage,
          'message': smsMsg,
        };

        debugPrint(">>> SMS PAYLOAD: ${jsonEncode(smsMessage)}");
        String result = await comCenterService.sendMessage(smsMessage);

        if (result == 'OK') {
          _showSnackBar('SMS sent successfully');
        } else {
          _showSnackBar('Failed to send SMS: $result');
        }
      }

      if (_whatsapp == 1) {
        final whatsappMessage = {
          '_id': 'whatsapp_center:$idPart:${Util.uuidv4()}',
          ...baseMessage,
          'message': [msgUrl, _generatedOtp],
          'template': 'hc_proforma_invoice',
        };

        debugPrint(">>> WHATSAPP PAYLOAD: ${jsonEncode(whatsappMessage)}");
        String result = await comCenterService.sendMessage(whatsappMessage);

        if (result == 'OK') {
          _showSnackBar('WhatsApp sent successfully');
        } else {
          _showSnackBar('Failed to send WhatsApp: $result');
        }
      }

      if (_email == 1) {
        final emailMessage = {
          '_id': 'email_center:$idPart:${Util.uuidv4()}',
          ...baseMessage,
        };

        debugPrint(">>> EMAIL PAYLOAD: ${jsonEncode(emailMessage)}");
        String result = await comCenterService.sendMessage(emailMessage);

        if (result == 'OK') {
          _showSnackBar('Email sent successfully');
        } else {
          _showSnackBar('Failed to send Email: $result');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending OTP: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar('Error sending OTP: $e');
    }
  }

  Future<void> _sendNotification() async {
    try {
      debugPrint('=== SEND NOTIFICATION START ===');

      if (_workOrder == null) {
        debugPrint('❌ Work order is null');
        return;
      }

      if (Settings.development) {
        debugPrint('🔧 Development mode: Notification NOT sent to manager');
        debugPrint(
            '📋 Would notify: ${_workOrder!.managerName} (ID: ${_workOrder!.managerId})');
        debugPrint('📄 Work order: ${_workOrder!.docId}');
        _showSnackBar('Dev Mode: Notification skipped');
        debugPrint('=== SEND NOTIFICATION END (DEV MODE) ===');
        return;
      }

      final notificationService = ref.read(notificationCenterServiceProvider);

      final appointmentDate =
          DateFormat('dd-MM-yyyy').format(_workOrder!.visitDate);

      String result = await notificationService.sendWorkOrderCompleted(
        appointmentDate: appointmentDate,
        appointmentTime: _workOrder!.visitTime,
        patientName: _workOrder!.patientName,
        age: _workOrder!.age,
        gender: _workOrder!.gender,
        address: _workOrder!.address,
        mobile: _workOrder!.mobile,
        pincode: _workOrder!.pincode,
        freeText: _workOrder!.freeText,
        managerId: _workOrder!.managerId?.toString() ?? '',
        managerName: _workOrder!.managerName,
      );

      if (result == 'OK') {
        debugPrint('✅ Manager notification sent successfully');
        _showSnackBar('Manager notified successfully');
      } else {
        debugPrint('❌ Manager notification failed: $result');
        _showSnackBar('Failed to notify manager');
      }

      debugPrint('=== SEND NOTIFICATION END ===');
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending notification: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar('Error: $e');
    }
  }

  void _onStepContinue() {
    if (_currentStep == 0)
      _afterFirstStep();
    else if (_currentStep == 1)
      _afterSecondStep();
    else if (_currentStep == 2)
      _afterThirdStep();
    else if (_currentStep == 3)
      _verifyOtp();
    else if (_currentStep == 4) _afterFifthStep();
  }

  void _onStepCancel() {
    if (_currentStep > 0) setState(() => _currentStep -= 1);
  }

  void _showSnackBar(String message) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 2)));
  }
}

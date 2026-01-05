import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/models/technician_process_doc.dart';

/// Immutable state for HC Process workflow
@immutable
class HCProcessState {
  // Core state
  final bool isLoading;
  final int currentStep;
  final String? errorMessage;
  final WorkOrder? workOrder;
  final TechnicianProcessDoc? processDoc;

  // Step 1: Delay
  final String delayReason;
  final String delayMins;

  // Step 2: Tests
  final List<Map<String, dynamic>> selectedTests;
  final double totalAmount;
  final bool cghsPrice;
  final String proformaInvLoc;

  // Step 3: Billing
  final double billAmount;
  final double discount;
  final double amountAfterDiscount;
  final double amountReceived;
  final double hcCharges;
  final double disposableCharges;
  final bool creditClient;
  final bool trialClient;

  // Step 4: OTP
  final String generatedOtp;
  final String enteredOtp;
  final String clientMobile;
  final String techMobile;

  // Step 5: Prescription Photos
  final List<String> uploadedPhotos;
  final List<String> uploadedPhotoPaths;
  final bool offlineMode;

  // Step 6: Payment
  final String paymentMethod;
  final String gpayRef;
  final String remarks;

  // Client info
  final bool b2bClient;
  final String b2bClientDetail;
  final int sms;
  final int whatsapp;
  final int email;

  const HCProcessState({
    this.isLoading = false,
    this.currentStep = 0,
    this.errorMessage,
    this.workOrder,
    this.processDoc,
    // Step 1
    this.delayReason = '',
    this.delayMins = '',
    // Step 2
    this.selectedTests = const [],
    this.totalAmount = 0,
    this.cghsPrice = false,
    this.proformaInvLoc = '',
    // Step 3
    this.billAmount = 0,
    this.discount = 0,
    this.amountAfterDiscount = 0,
    this.amountReceived = 0,
    this.hcCharges = 50,
    this.disposableCharges = 30,
    this.creditClient = false,
    this.trialClient = false,
    // Step 4
    this.generatedOtp = '',
    this.enteredOtp = '',
    this.clientMobile = '',
    this.techMobile = '',
    // Step 5
    this.uploadedPhotos = const [],
    this.uploadedPhotoPaths = const [],
    this.offlineMode = false,
    // Step 6
    this.paymentMethod = 'cash',
    this.gpayRef = 'Later',
    this.remarks = '',
    // Client info
    this.b2bClient = false,
    this.b2bClientDetail = '',
    this.sms = 0,
    this.whatsapp = 0,
    this.email = 0,
  });

  /// Create a copy with updated values
  HCProcessState copyWith({
    bool? isLoading,
    int? currentStep,
    String? errorMessage,
    WorkOrder? workOrder,
    TechnicianProcessDoc? processDoc,
    // Step 1
    String? delayReason,
    String? delayMins,
    // Step 2
    List<Map<String, dynamic>>? selectedTests,
    double? totalAmount,
    bool? cghsPrice,
    String? proformaInvLoc,
    // Step 3
    double? billAmount,
    double? discount,
    double? amountAfterDiscount,
    double? amountReceived,
    double? hcCharges,
    double? disposableCharges,
    bool? creditClient,
    bool? trialClient,
    // Step 4
    String? generatedOtp,
    String? enteredOtp,
    String? clientMobile,
    String? techMobile,
    // Step 5
    List<String>? uploadedPhotos,
    List<String>? uploadedPhotoPaths,
    bool? offlineMode,
    // Step 6
    String? paymentMethod,
    String? gpayRef,
    String? remarks,
    // Client info
    bool? b2bClient,
    String? b2bClientDetail,
    int? sms,
    int? whatsapp,
    int? email,
  }) {
    return HCProcessState(
      isLoading: isLoading ?? this.isLoading,
      currentStep: currentStep ?? this.currentStep,
      errorMessage: errorMessage,
      workOrder: workOrder ?? this.workOrder,
      processDoc: processDoc ?? this.processDoc,
      delayReason: delayReason ?? this.delayReason,
      delayMins: delayMins ?? this.delayMins,
      selectedTests: selectedTests ?? this.selectedTests,
      totalAmount: totalAmount ?? this.totalAmount,
      cghsPrice: cghsPrice ?? this.cghsPrice,
      proformaInvLoc: proformaInvLoc ?? this.proformaInvLoc,
      billAmount: billAmount ?? this.billAmount,
      discount: discount ?? this.discount,
      amountAfterDiscount: amountAfterDiscount ?? this.amountAfterDiscount,
      amountReceived: amountReceived ?? this.amountReceived,
      hcCharges: hcCharges ?? this.hcCharges,
      disposableCharges: disposableCharges ?? this.disposableCharges,
      creditClient: creditClient ?? this.creditClient,
      trialClient: trialClient ?? this.trialClient,
      generatedOtp: generatedOtp ?? this.generatedOtp,
      enteredOtp: enteredOtp ?? this.enteredOtp,
      clientMobile: clientMobile ?? this.clientMobile,
      techMobile: techMobile ?? this.techMobile,
      uploadedPhotos: uploadedPhotos ?? this.uploadedPhotos,
      uploadedPhotoPaths: uploadedPhotoPaths ?? this.uploadedPhotoPaths,
      offlineMode: offlineMode ?? this.offlineMode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gpayRef: gpayRef ?? this.gpayRef,
      remarks: remarks ?? this.remarks,
      b2bClient: b2bClient ?? this.b2bClient,
      b2bClientDetail: b2bClientDetail ?? this.b2bClientDetail,
      sms: sms ?? this.sms,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
    );
  }

  /// Check if process can proceed to finish
  bool get canFinish => uploadedPhotoPaths.isNotEmpty;

  /// Check if client needs OTP
  bool get needsOtp => !b2bClient && !trialClient && !creditClient;

  /// Get patient name for display
  String get patientName => workOrder?.patientName ?? 'Unknown';

  /// Get patient info summary
  String get patientInfo {
    if (workOrder == null) return '';
    return '${workOrder!.patientName} | ${workOrder!.mobile}';
  }
}

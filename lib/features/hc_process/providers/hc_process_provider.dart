import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/hc_process_state.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/models/technician_process_doc.dart';

// Re-export state for convenience
export '../domain/hc_process_state.dart';

/// StateNotifier for HC Process state management
/// Manages state only - delegates business logic to HCProcessController
class HCProcessNotifier extends StateNotifier<HCProcessState> {
  final Ref _ref;
  final String workOrderId;

  HCProcessNotifier(this._ref, this.workOrderId)
      : super(const HCProcessState());

  // ==================== Core State Updates ====================

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setCurrentStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  void setWorkOrderData({
    required WorkOrder workOrder,
    required TechnicianProcessDoc processDoc,
    required String clientMobile,
    required String techMobile,
    required bool b2bClient,
    required String b2bClientDetail,
    required bool creditClient,
    required bool trialClient,
    required int sms,
    required int whatsapp,
    required int email,
  }) {
    state = state.copyWith(
      workOrder: workOrder,
      processDoc: processDoc,
      clientMobile: clientMobile,
      techMobile: techMobile,
      b2bClient: b2bClient,
      b2bClientDetail: b2bClientDetail,
      creditClient: creditClient,
      trialClient: trialClient,
      sms: sms,
      whatsapp: whatsapp,
      email: email,
    );
  }

  void updateProcessDoc(TechnicianProcessDoc processDoc) {
    state = state.copyWith(processDoc: processDoc);
  }

  void updateWorkOrder(WorkOrder workOrder) {
    state = state.copyWith(workOrder: workOrder);
  }

  // ==================== Step 1: Delay ====================

  void setDelayReason(String reason) {
    state = state.copyWith(delayReason: reason);
  }

  void setDelayMins(String mins) {
    state = state.copyWith(delayMins: mins);
  }

  // ==================== Step 2: Tests ====================

  void setSelectedTests(List<Map<String, dynamic>> tests) {
    state = state.copyWith(selectedTests: tests);
  }

  void addTest(Map<String, dynamic> test) {
    final updatedTests = [...state.selectedTests, test];
    state = state.copyWith(selectedTests: updatedTests);
  }

  void removeTest(int index) {
    final updatedTests = [...state.selectedTests];
    updatedTests.removeAt(index);
    state = state.copyWith(selectedTests: updatedTests);
  }

  void setTotalAmount(double amount) {
    state = state.copyWith(totalAmount: amount);
  }

  void setCghsPrice(bool cghs) {
    state = state.copyWith(cghsPrice: cghs);
  }

  void setProformaInvLoc(String loc) {
    state = state.copyWith(proformaInvLoc: loc);
  }

  // ==================== Step 3: Billing ====================

  void setBillAmount(double amount) {
    state = state.copyWith(billAmount: amount);
  }

  void setDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  void setAmountAfterDiscount(double amount) {
    state = state.copyWith(amountAfterDiscount: amount);
  }

  void setAmountReceived(double amount) {
    state = state.copyWith(amountReceived: amount);
  }

  void setHcCharges(double charges) {
    state = state.copyWith(hcCharges: charges);
  }

  void setDisposableCharges(double charges) {
    state = state.copyWith(disposableCharges: charges);
  }

  void updateBillingState({
    double? billAmount,
    double? discount,
    double? amountAfterDiscount,
    double? amountReceived,
  }) {
    state = state.copyWith(
      billAmount: billAmount,
      discount: discount,
      amountAfterDiscount: amountAfterDiscount,
      amountReceived: amountReceived,
    );
  }

  // ==================== Step 4: OTP ====================

  void setGeneratedOtp(String otp) {
    state = state.copyWith(generatedOtp: otp);
  }

  void setEnteredOtp(String otp) {
    state = state.copyWith(enteredOtp: otp);
  }

  // ==================== Step 5: Photos ====================

  void setOfflineMode(bool offline) {
    // Clear photos when switching modes
    state = state.copyWith(
      offlineMode: offline,
      uploadedPhotos: [],
      uploadedPhotoPaths: [],
    );
  }

  void addUploadedPhoto(String name, String path) {
    state = state.copyWith(
      uploadedPhotos: [...state.uploadedPhotos, name],
      uploadedPhotoPaths: [...state.uploadedPhotoPaths, path],
    );
  }

  void removePhoto(int index) {
    final photos = [...state.uploadedPhotos];
    final paths = [...state.uploadedPhotoPaths];
    photos.removeAt(index);
    paths.removeAt(index);
    state = state.copyWith(
      uploadedPhotos: photos,
      uploadedPhotoPaths: paths,
    );
  }

  // ==================== Step 6: Payment ====================

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setGpayRef(String ref) {
    state = state.copyWith(gpayRef: ref);
  }

  void setRemarks(String remarks) {
    state = state.copyWith(remarks: remarks);
  }
}

/// Provider for HC Process state
/// Uses .family to create separate instances per workOrderId
final hcProcessProvider = StateNotifierProvider.autoDispose
    .family<HCProcessNotifier, HCProcessState, String>((ref, workOrderId) {
  return HCProcessNotifier(ref, workOrderId);
});

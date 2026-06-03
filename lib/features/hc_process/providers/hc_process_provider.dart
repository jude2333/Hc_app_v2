import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/hc_process_state.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/models/technician_process_doc.dart';

export '../domain/hc_process_state.dart';

class HCProcessNotifier extends StateNotifier<HCProcessState> {
  final Ref _ref;
  final String workOrderId;

  HCProcessNotifier(this._ref, this.workOrderId)
      : super(const HCProcessState());

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

  void setDelayReason(String reason) {
    state = state.copyWith(delayReason: reason);
  }

  void setDelayMins(String mins) {
    state = state.copyWith(delayMins: mins);
  }

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

  void applyTestDiscount(int index, double value, bool isFlat) {
    if (index < 0 || index >= state.selectedTests.length) return;

    final tests =
        state.selectedTests.map((t) => Map<String, dynamic>.from(t)).toList();
    final test = tests[index];

    final baseCost = double.tryParse(test['base_cost']?.toString() ?? '0') ?? 0;
    final cghsCost =
        double.tryParse(test['cghs_price']?.toString() ?? '0') ?? 0;
    final activePrice = (state.cghsPrice && cghsCost > 0) ? cghsCost : baseCost;

    double discountedPrice;
    if (isFlat) {
      discountedPrice = (activePrice - value).clamp(0, activePrice);
    } else {
      discountedPrice = activePrice - (activePrice * value / 100);
      discountedPrice = discountedPrice.clamp(0, activePrice);
    }

    test['discount_value'] = value;
    test['discount_type'] = isFlat ? 'flat' : 'percent';
    test['discounted_price'] = discountedPrice;
    tests[index] = test;

    final newTotal = _recomputeTestTotal(tests);
    state = state.copyWith(
      selectedTests: tests,
      totalAmount: newTotal,
      billAmount: newTotal,
    );
  }

  void clearTestDiscount(int index) {
    if (index < 0 || index >= state.selectedTests.length) return;

    final tests =
        state.selectedTests.map((t) => Map<String, dynamic>.from(t)).toList();
    final test = tests[index];

    test.remove('discount_value');
    test.remove('discount_type');
    test.remove('discounted_price');
    tests[index] = test;

    final newTotal = _recomputeTestTotal(tests);
    state = state.copyWith(
      selectedTests: tests,
      totalAmount: newTotal,
      billAmount: newTotal,
    );
  }

  double _recomputeTestTotal(List<Map<String, dynamic>> tests) {
    double total = 0;
    for (final t in tests) {
      final dp = double.tryParse(t['discounted_price']?.toString() ?? '');
      if (dp != null) {
        total += dp;
      } else {
        final bc = double.tryParse(t['base_cost']?.toString() ?? '0') ?? 0;
        final cc = double.tryParse(t['cghs_price']?.toString() ?? '0') ?? 0;
        total += (state.cghsPrice && cc > 0) ? cc : bc;
      }
    }
    return total;
  }

  void setCghsPrice(bool cghs) {
    state = state.copyWith(cghsPrice: cghs);
  }

  void setCreditClient(bool credit) {
    state = state.copyWith(creditClient: credit);
  }

  void setProformaInvLoc(String loc) {
    state = state.copyWith(proformaInvLoc: loc);
  }

  void setBillAmount(double amount) {
    state = state.copyWith(billAmount: amount);
  }

  void setDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  void setDiscountMode(bool isFlat) {
    state = state.copyWith(isDiscountFlat: isFlat, discount: 0);
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

  void setGeneratedOtp(String otp) {
    state = state.copyWith(generatedOtp: otp);
  }

  void setEnteredOtp(String otp) {
    state = state.copyWith(enteredOtp: otp);
  }

  void setOfflineMode(bool offline) {
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

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setGpayRef(String ref) {
    state = state.copyWith(gpayRef: ref);
  }

  void setRemarks(String remarks) {
    state = state.copyWith(remarks: remarks);
  }

  void setSkipMessage(String? message) {
    state = state.copyWith(skipMessage: message);
  }

  void clearSkipMessage() {
    state = state.copyWith(skipMessage: null);
  }
}

final hcProcessProvider = StateNotifierProvider.autoDispose
    .family<HCProcessNotifier, HCProcessState, String>((ref, workOrderId) {
  return HCProcessNotifier(ref, workOrderId);
});

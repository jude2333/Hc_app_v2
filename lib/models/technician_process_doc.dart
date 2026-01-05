import 'dart:convert';

/// Model representing the technician's HC Process document structure
/// This wraps the nested JSON stored in the `doc` column of hc_patient_visit_detail
class TechnicianProcessDoc {
  // Process Steps
  final ProcessSteps process;

  // Test Items (from price list selection)
  final List<TestItem> testItems;

  // Timeline entries
  final List<String> timeLine;

  // Financial fields
  final double? total;
  final double? discount;
  final double? hcCharges;
  final double? disposableCharges;
  final String? amountReceived;
  final String? paymentMethod;
  final String? gpayRef;
  final String? remarks;

  final int? credit;
  final int? cghs;

  // Status fields
  final String? status;
  final String? serverStatus;

  // Lab/billing fields
  final String? billNumber;
  final String? labNumber;
  final String? labSamplePics;

  // Settings
  final ProcessSettings settings;

  // Metadata
  final String? updatedAt;

  TechnicianProcessDoc({
    ProcessSteps? process,
    List<TestItem>? testItems,
    List<String>? timeLine,
    this.total,
    this.discount,
    this.hcCharges,
    this.disposableCharges,
    this.amountReceived,
    this.paymentMethod,
    this.gpayRef,
    this.remarks,
    this.credit, // ✅ Added
    this.cghs, // ✅ Added
    this.status,
    this.serverStatus,
    this.billNumber,
    this.labNumber,
    this.labSamplePics,
    ProcessSettings? settings,
    this.updatedAt,
  })  : process = process ?? ProcessSteps(),
        testItems = testItems ?? [],
        timeLine = timeLine ?? [],
        settings = settings ?? ProcessSettings();

  factory TechnicianProcessDoc.fromJson(Map<String, dynamic> json) {
    return TechnicianProcessDoc(
      process: ProcessSteps.fromJson(json['process'] ?? {}),
      testItems: (json['test_items'] as List<dynamic>?)
              ?.map((item) => TestItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      timeLine: (json['time_line'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      total: json['total'] != null ? (json['total'] as num).toDouble() : null,
      discount: json['discount'] != null
          ? double.tryParse(json['discount'].toString())
          : null,
      hcCharges: json['hc_charges'] != null
          ? double.tryParse(json['hc_charges'].toString())
          : null,
      disposableCharges: json['disposable_charges'] != null
          ? double.tryParse(json['disposable_charges'].toString())
          : null,
      amountReceived: json['amount_received']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      gpayRef: json['gpay_ref']?.toString(),
      remarks: json['remarks']?.toString(),

      // ✅ Parse Flags
      credit: int.tryParse(json['credit']?.toString() ?? ''),
      cghs: int.tryParse(json['cghs']?.toString() ?? ''),

      status: json['status']?.toString(),
      serverStatus: json['server_status']?.toString(),
      billNumber: json['bill_number']?.toString(),
      labNumber: json['lab_number']?.toString(),
      labSamplePics: json['lab_sample_pics']?.toString(),
      settings: ProcessSettings.fromJson(json['settings'] ?? {}),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'process': process.toJson(),
      'test_items': testItems.map((item) => item.toJson()).toList(),
      'time_line': timeLine,
      'total': total,
      'discount': discount,
      'hc_charges': hcCharges,
      'disposable_charges': disposableCharges,
      'amount_received': amountReceived,
      'payment_method': paymentMethod,
      'gpay_ref': gpayRef,
      'remarks': remarks,

      // ✅ Serialize Flags
      'credit': credit,
      'cghs': cghs,

      'status': status,
      'server_status': serverStatus,
      'bill_number': billNumber,
      'lab_number': labNumber,
      'lab_sample_pics': labSamplePics,
      'settings': settings.toJson(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  TechnicianProcessDoc copyWith({
    ProcessSteps? process,
    List<TestItem>? testItems,
    List<String>? timeLine,
    double? total,
    double? discount,
    double? hcCharges,
    double? disposableCharges,
    String? amountReceived,
    String? paymentMethod,
    String? gpayRef,
    String? remarks,

    // ✅ Add to copyWith arguments
    int? credit,
    int? cghs,
    String? status,
    String? serverStatus,
    String? billNumber,
    String? labNumber,
    String? labSamplePics,
    ProcessSettings? settings,
    String? updatedAt,
  }) {
    return TechnicianProcessDoc(
      process: process ?? this.process,
      testItems: testItems ?? this.testItems,
      timeLine: timeLine ?? this.timeLine,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      hcCharges: hcCharges ?? this.hcCharges,
      disposableCharges: disposableCharges ?? this.disposableCharges,
      amountReceived: amountReceived ?? this.amountReceived,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gpayRef: gpayRef ?? this.gpayRef,
      remarks: remarks ?? this.remarks,

      // ✅ Assign Flags
      credit: credit ?? this.credit,
      cghs: cghs ?? this.cghs,

      status: status ?? this.status,
      serverStatus: serverStatus ?? this.serverStatus,
      billNumber: billNumber ?? this.billNumber,
      labNumber: labNumber ?? this.labNumber,
      labSamplePics: labSamplePics ?? this.labSamplePics,
      settings: settings ?? this.settings,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Add a timeline entry
  TechnicianProcessDoc addTimelineEntry(String entry) {
    return copyWith(
      timeLine: [...timeLine, entry],
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Update process step
  TechnicianProcessDoc updateProcessStep(String stepName, String value) {
    return copyWith(
      process: process.updateStep(stepName, value),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Add test item
  TechnicianProcessDoc addTestItem(TestItem item) {
    return copyWith(
      testItems: [...testItems, item],
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  /// Calculate total from test items
  double calculateTotal() {
    return testItems.fold(0.0, (sum, item) => sum + (item.baseCost ?? 0));
  }
}

/// Process steps model
class ProcessSteps {
  final String? firstStep;
  final String? secondStep;
  final String? thirdStep;
  final String? fourthStep;
  final String? fifthStep;
  final String? prescriptionUploadedAt;
  final String? proformaUploadedAt;

  ProcessSteps({
    this.firstStep,
    this.secondStep,
    this.thirdStep,
    this.fourthStep,
    this.fifthStep,
    this.prescriptionUploadedAt,
    this.proformaUploadedAt,
  });

  factory ProcessSteps.fromJson(Map<String, dynamic> json) {
    return ProcessSteps(
      firstStep: json['first_step']?.toString(),
      secondStep: json['second_step']?.toString(),
      thirdStep: json['third_step']?.toString(),
      fourthStep: json['fourth_step']?.toString(),
      fifthStep: json['fifth_step']?.toString(),
      prescriptionUploadedAt: json['prescription_uploaded_at']?.toString(),
      proformaUploadedAt: json['proforma_uploaded_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_step': firstStep ?? '',
      'second_step': secondStep ?? '',
      'third_step': thirdStep ?? '',
      'fourth_step': fourthStep ?? '',
      'fifth_step': fifthStep ?? '',
      'prescription_uploaded_at': prescriptionUploadedAt ?? '',
      'proforma_uploaded_at': proformaUploadedAt ?? '',
    };
  }

  ProcessSteps copyWith({
    String? firstStep,
    String? secondStep,
    String? thirdStep,
    String? fourthStep,
    String? fifthStep,
    String? prescriptionUploadedAt,
    String? proformaUploadedAt,
  }) {
    return ProcessSteps(
      firstStep: firstStep ?? this.firstStep,
      secondStep: secondStep ?? this.secondStep,
      thirdStep: thirdStep ?? this.thirdStep,
      fourthStep: fourthStep ?? this.fourthStep,
      fifthStep: fifthStep ?? this.fifthStep,
      prescriptionUploadedAt:
          prescriptionUploadedAt ?? this.prescriptionUploadedAt,
      proformaUploadedAt: proformaUploadedAt ?? this.proformaUploadedAt,
    );
  }

  /// Helper to update a specific step
  ProcessSteps updateStep(String stepName, String value) {
    switch (stepName) {
      case 'first_step':
        return copyWith(firstStep: value);
      case 'second_step':
        return copyWith(secondStep: value);
      case 'third_step':
        return copyWith(thirdStep: value);
      case 'fourth_step':
        return copyWith(fourthStep: value);
      case 'fifth_step':
        return copyWith(fifthStep: value);
      case 'prescription_uploaded_at':
        return copyWith(prescriptionUploadedAt: value);
      case 'proforma_uploaded_at':
        return copyWith(proformaUploadedAt: value);
      default:
        return this;
    }
  }
}

/// Test item model
class TestItem {
  final String? deptId;
  final String? deptName;
  final String? investId;
  final String? investName;
  final String? rateCardName;
  final double? baseCost;
  final double? minCost;
  final double? cghsPrice;

  TestItem({
    this.deptId,
    this.deptName,
    this.investId,
    this.investName,
    this.rateCardName,
    this.baseCost,
    this.minCost,
    this.cghsPrice,
  });

  factory TestItem.fromJson(Map<String, dynamic> json) {
    return TestItem(
      deptId: json['dept_id']?.toString(),
      deptName: json['dept_name']?.toString(),
      investId: json['invest_id']?.toString(),
      investName: json['invest_name']?.toString(),
      rateCardName: json['rate_card_name']?.toString(),
      baseCost: json['base_cost'] != null
          ? double.tryParse(json['base_cost'].toString())
          : null,
      minCost: json['min_cost'] != null
          ? double.tryParse(json['min_cost'].toString())
          : null,
      cghsPrice: json['cghs_price'] != null
          ? double.tryParse(json['cghs_price'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dept_id': deptId,
      'dept_name': deptName,
      'invest_id': investId,
      'invest_name': investName,
      'rate_card_name': rateCardName,
      'base_cost': baseCost?.toString() ?? '0',
      'min_cost': minCost?.toString() ?? '0',
      'cghs_price': cghsPrice?.toString() ?? '0',
    };
  }
}

/// Settings model
class ProcessSettings {
  final int sendSms;
  final int sendWhatsapp;
  final int sendEmail;

  ProcessSettings({
    this.sendSms = 1,
    this.sendWhatsapp = 1,
    this.sendEmail = 1,
  });

  factory ProcessSettings.fromJson(Map<String, dynamic> json) {
    return ProcessSettings(
      sendSms: json['send_sms'] as int? ?? 1,
      sendWhatsapp: json['send_whatsapp'] as int? ?? 1,
      sendEmail: json['send_email'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'send_sms': sendSms,
      'send_whatsapp': sendWhatsapp,
      'send_email': sendEmail,
    };
  }
}

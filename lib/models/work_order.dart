import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// Pre-cached formatters (static to avoid recreating)
final DateFormat _displayDateFormat = DateFormat('yyyy-MM-dd');
final DateFormat _shortDateFormat = DateFormat('dd-MM-yyyy');
final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

@immutable
class WorkOrder {
  final String id;
  final int? tenantId;
  final int? hcpmId;
  final String docId;

  // Patient Info
  final String patientName;
  final DateTime visitDate;
  final String visitTime;
  final String doctorName;

  // Provider & Assignment
  final int? proId;
  final int? managerId;
  final String managerName;
  final int? assignedId;
  final String assignedTo;

  // B2B Client
  final int? b2bClientId;
  final String b2bClientName;

  // Status
  final String status;
  final String serverStatus;

  // Financial
  final double billAmount;
  final double receivedAmount;
  final double discountAmount;

  // Full Document (Lazy Loaded)
  final String? _rawDocString;

  // ✅ OPTIMIZATION 1: The Immutable Source of Truth for nested data
  final Map<String, dynamic> parsedDocMap;

  // Bill & Lab
  final String billNumber;
  final String labNumber;

  // Audit
  final bool visible;
  final String createdBy;
  final DateTime createdAt;
  final String lastUpdatedBy;
  final DateTime lastUpdatedAt;

  // ✅ PRE-CACHED FORMATTED STRINGS (computed once at construction)
  final String formattedVisitDate; // 'yyyy-MM-dd'
  final String formattedShortDate; // 'dd-MM-yyyy'
  final String formattedBillAmount; // '₹1,234'
  final String formattedReceivedAmount; // '₹1,234'
  final String formattedDiscountAmount; // '₹1,234'
  final String searchableText; // Pre-computed lowercase searchable string

  // Private constructor used by factory
  WorkOrder._internal({
    required this.id,
    this.tenantId,
    this.hcpmId,
    required this.docId,
    required this.patientName,
    required this.visitDate,
    required this.visitTime,
    required this.doctorName,
    this.proId,
    this.managerId,
    required this.managerName,
    this.assignedId,
    required this.assignedTo,
    this.b2bClientId,
    required this.b2bClientName,
    required this.status,
    required this.serverStatus,
    required this.billAmount,
    required this.receivedAmount,
    required this.discountAmount,
    String? doc,
    required this.parsedDocMap,
    required this.billNumber,
    required this.labNumber,
    required this.visible,
    required this.createdBy,
    required this.createdAt,
    required this.lastUpdatedBy,
    required this.lastUpdatedAt,
    required this.formattedVisitDate,
    required this.formattedShortDate,
    required this.formattedBillAmount,
    required this.formattedReceivedAmount,
    required this.formattedDiscountAmount,
    required this.searchableText,
  }) : _rawDocString = doc;

  // ✅ Factory constructor that pre-computes formatted strings
  factory WorkOrder({
    required String id,
    int? tenantId,
    int? hcpmId,
    required String docId,
    required String patientName,
    required DateTime visitDate,
    required String visitTime,
    required String doctorName,
    int? proId,
    int? managerId,
    required String managerName,
    int? assignedId,
    required String assignedTo,
    int? b2bClientId,
    required String b2bClientName,
    required String status,
    required String serverStatus,
    required double billAmount,
    required double receivedAmount,
    required double discountAmount,
    String? doc,
    required Map<String, dynamic> parsedDocMap,
    required String billNumber,
    required String labNumber,
    required bool visible,
    required String createdBy,
    required DateTime createdAt,
    required String lastUpdatedBy,
    required DateTime lastUpdatedAt,
  }) {
    // Pre-compute formatted strings
    final formattedVisitDate = _displayDateFormat.format(visitDate);
    final mobile = parsedDocMap['mobile']?.toString() ?? '';

    return WorkOrder._internal(
      id: id,
      tenantId: tenantId,
      hcpmId: hcpmId,
      docId: docId,
      patientName: patientName,
      visitDate: visitDate,
      visitTime: visitTime,
      doctorName: doctorName,
      proId: proId,
      managerId: managerId,
      managerName: managerName,
      assignedId: assignedId,
      assignedTo: assignedTo,
      b2bClientId: b2bClientId,
      b2bClientName: b2bClientName,
      status: status,
      serverStatus: serverStatus,
      billAmount: billAmount,
      receivedAmount: receivedAmount,
      discountAmount: discountAmount,
      doc: doc,
      parsedDocMap: parsedDocMap,
      billNumber: billNumber,
      labNumber: labNumber,
      visible: visible,
      createdBy: createdBy,
      createdAt: createdAt,
      lastUpdatedBy: lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt,
      formattedVisitDate: formattedVisitDate,
      formattedShortDate: _shortDateFormat.format(visitDate),
      formattedBillAmount: _currencyFormat.format(billAmount),
      formattedReceivedAmount: _currencyFormat.format(receivedAmount),
      formattedDiscountAmount: _currencyFormat.format(discountAmount),
      // Pre-compute searchable lowercase string for fast filtering
      searchableText:
          '$patientName|$mobile|$doctorName|$assignedTo|$billNumber|$status'
              .toLowerCase(),
    );
  }

  // ✅ COMPATIBILITY GETTER (Prevents errors in other files)
  Map<String, dynamic> get parsedDoc => parsedDocMap;

  // Lazy doc getter
  String get doc => _rawDocString ?? jsonEncode(parsedDocMap);

  // ✅ OPTIMIZATION 4: Robust Equality Check
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WorkOrder &&
        other.id == id &&
        // Normalize time to seconds to avoid millisecond redraws
        other.lastUpdatedAt.millisecondsSinceEpoch ~/ 1000 ==
            lastUpdatedAt.millisecondsSinceEpoch ~/ 1000 &&
        other.status == status &&
        other.serverStatus == serverStatus &&
        other.assignedId == assignedId &&
        // Normalize doubles to avoid micro-precision diffs
        (other.billAmount - billAmount).abs() < 0.01 &&
        (other.receivedAmount - receivedAmount).abs() < 0.01;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      lastUpdatedAt.millisecondsSinceEpoch ~/ 1000,
      status,
      serverStatus,
      assignedId,
      (billAmount * 100).toInt(),
    );
  }

  // Reconstructs the JSON map structure (Used for DB saving)
  Map<String, dynamic> buildDoc() {
    return {
      '_id': docId,
      'old_id': parsedDocMap['old_id'] ?? '',
      'name': patientName,
      'age': parsedDocMap['age'] ?? 'NA',
      'gender': parsedDocMap['gender'] ?? 'Male',
      'address': address,
      'email': email,
      'pincode': pincode,
      'mobile': mobile,
      'doctor_name': doctorName,
      'pro_id': parsedDocMap['pro_id'] ?? '',
      'b2b_client_id': b2bClientId ?? 0,
      'b2b_client_name': b2bClientName,
      'vip_client': parsedDocMap['vip_client'] ?? 0,
      'urgent': parsedDocMap['urgent'] ?? 0,
      'credit': parsedDocMap['credit'] ?? 0,
      'appointment_date': DateFormat('dd-MM-yyyy').format(visitDate),
      'appointment_time': visitTime,
      'pres_photo': prescriptionPath,
      'status': status,
      'server_status': serverStatus,
      'assigned_to': assignedTo,
      'assigned_id': assignedId ?? 0,
      'free_text': parsedDocMap['free_text'] ?? '',
      'process': parsedDocMap['process'] ?? {},
      'settings': parsedDocMap['settings'] ??
          {'send_sms': 1, 'send_whatsapp': 1, 'send_email': 1},
      'updated_at': DateTime.now().toIso8601String(),
      'sort_time': visitDate.millisecondsSinceEpoch,
      'manager_id': managerId?.toString() ?? '',
      'manager_name': managerName,
      'tenant_id': tenantId?.toString() ?? '',
      'time_line': timeLine,
      'test_items': parsedDocMap['test_items'] ?? [],
      'total': parsedDocMap['total'] ?? 0,
      'amount_received': parsedDocMap['amount_received'] ?? '',
      'discount': parsedDocMap['discount'] ?? '0',
      'hc_charges': parsedDocMap['hc_charges'] ?? '0',
      'disposable_charges': parsedDocMap['disposable_charges'] ?? '0',
      'payment_method': parsedDocMap['payment_method'] ?? '',
      'gpay_ref': parsedDocMap['gpay_ref'] ?? '',
      'bill_number': billNumber,
      'lab_number': labNumber,
      'remarks': parsedDocMap['remarks'] ?? '',
      'report_status': parsedDocMap['report_status'] ?? '',
      'status_in_number': parsedDocMap['status_in_number'] ?? '',
      'report_path': parsedDocMap['report_path'] ?? '',
      'cancel_reason': parsedDocMap['cancel_reason'] ?? '',
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'hcpm_id': hcpmId,
      'doc_id': docId,
      'patient_name': patientName,
      'visit_date': visitDate.toIso8601String().split('T')[0],
      'visit_time': visitTime,
      'doctor_name': doctorName,
      'pro_id': proId,
      'manager_id': managerId,
      'manager_name': managerName,
      'assigned_id': assignedId,
      'assigned_to': assignedTo,
      'b2b_client_id': b2bClientId,
      'b2b_client_name': b2bClientName,
      'status': status,
      'server_status': serverStatus,
      'bill_amount': billAmount,
      'received_amount': receivedAmount,
      'discount_amount': discountAmount,
      'doc': jsonEncode(buildDoc()), // Encode only when saving
      'bill_number': billNumber,
      'lab_number': labNumber,
      'visible': visible ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'last_updated_by': lastUpdatedBy,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }

  // Helper to deep copy JSON maps
  static Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source));
  }

  WorkOrder copyWith({
    String? id,
    int? tenantId,
    int? hcpmId,
    String? docId,
    String? patientName,
    DateTime? visitDate,
    String? visitTime,
    String? doctorName,
    int? proId,
    int? managerId,
    String? managerName,
    int? assignedId,
    String? assignedTo,
    int? b2bClientId,
    String? b2bClientName,
    String? status,
    String? serverStatus,
    double? billAmount,
    double? receivedAmount,
    double? discountAmount,
    String? doc,
    String? billNumber,
    String? labNumber,
    bool? visible,
    String? createdBy,
    DateTime? createdAt,
    String? lastUpdatedBy,
    DateTime? lastUpdatedAt,

    // Nested fields
    String? age,
    String? gender,
    String? mobile,
    String? address,
    String? pincode,
    String? email,
    String? freeText,
    bool? vip,
    bool? urgent,
    int? credit,
    String? prescriptionPath,
    String? oldId,
    int? sortTime,
    Map<String, dynamic>? process,
    Map<String, dynamic>? settings,
    List<dynamic>? testItems,
    List<dynamic>? timeLine,
    double? total,
    String? amountReceived,
    String? discount,
    String? hcCharges,
    String? disposableCharges,
    String? paymentMethod,
    String? gpayRef,
    String? remarks,
  }) {
    // ✅ OPTIMIZATION 5: Deep Copy to break references
    final updatedDoc = _deepCopyMap(parsedDocMap);

    if (patientName != null) updatedDoc['name'] = patientName;
    if (doctorName != null) updatedDoc['doctor_name'] = doctorName;
    if (visitDate != null) {
      updatedDoc['appointment_date'] =
          DateFormat('dd-MM-yyyy').format(visitDate);
      updatedDoc['sort_time'] = visitDate.millisecondsSinceEpoch;
    }
    if (visitTime != null) updatedDoc['appointment_time'] = visitTime;
    if (b2bClientId != null) updatedDoc['b2b_client_id'] = b2bClientId;
    if (b2bClientName != null) updatedDoc['b2b_client_name'] = b2bClientName;
    if (status != null) updatedDoc['status'] = status;
    if (serverStatus != null) updatedDoc['server_status'] = serverStatus;
    if (assignedId != null) updatedDoc['assigned_id'] = assignedId;
    if (assignedTo != null) updatedDoc['assigned_to'] = assignedTo;
    if (managerId != null) updatedDoc['manager_id'] = managerId.toString();
    if (managerName != null) updatedDoc['manager_name'] = managerName;
    if (tenantId != null) updatedDoc['tenant_id'] = tenantId.toString();

    if (age != null) updatedDoc['age'] = age;
    if (gender != null) updatedDoc['gender'] = gender;
    if (mobile != null) updatedDoc['mobile'] = mobile;
    if (address != null) updatedDoc['address'] = address;
    if (pincode != null) updatedDoc['pincode'] = pincode;
    if (email != null) updatedDoc['email'] = email;
    if (freeText != null) updatedDoc['free_text'] = freeText;
    if (vip != null) updatedDoc['vip_client'] = vip ? 1 : 0;
    if (urgent != null) updatedDoc['urgent'] = urgent ? 1 : 0;
    if (credit != null) updatedDoc['credit'] = credit;
    if (prescriptionPath != null) updatedDoc['pres_photo'] = prescriptionPath;
    if (oldId != null) updatedDoc['old_id'] = oldId;
    if (sortTime != null) updatedDoc['sort_time'] = sortTime;

    if (process != null) {
      updatedDoc['process'] = process;
    } else if (prescriptionPath != null) {
      updatedDoc['process'] ??= {};
      updatedDoc['process']['fifth_step'] = prescriptionPath;
      if (prescriptionPath.isNotEmpty) {
        updatedDoc['process']['prescription_uploaded_at'] =
            DateTime.now().toIso8601String();
      }
    }

    if (settings != null) updatedDoc['settings'] = settings;
    if (testItems != null) updatedDoc['test_items'] = testItems;
    if (timeLine != null) updatedDoc['time_line'] = timeLine;

    if (total != null) updatedDoc['total'] = total;
    if (amountReceived != null) updatedDoc['amount_received'] = amountReceived;
    if (discount != null) updatedDoc['discount'] = discount;
    if (hcCharges != null) updatedDoc['hc_charges'] = hcCharges;
    if (disposableCharges != null)
      updatedDoc['disposable_charges'] = disposableCharges;
    if (paymentMethod != null) updatedDoc['payment_method'] = paymentMethod;
    if (gpayRef != null) updatedDoc['gpay_ref'] = gpayRef;
    if (remarks != null) updatedDoc['remarks'] = remarks;

    updatedDoc['updated_at'] =
        (lastUpdatedAt ?? DateTime.now()).toIso8601String();

    return WorkOrder(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      hcpmId: hcpmId ?? this.hcpmId,
      docId: docId ?? this.docId,
      patientName: patientName ?? this.patientName,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      doctorName: doctorName ?? this.doctorName,
      proId: proId ?? this.proId,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      assignedId: assignedId ?? this.assignedId,
      assignedTo: assignedTo ?? this.assignedTo,
      b2bClientId: b2bClientId ?? this.b2bClientId,
      b2bClientName: b2bClientName ?? this.b2bClientName,
      status: status ?? this.status,
      serverStatus: serverStatus ?? this.serverStatus,
      billAmount: billAmount ?? this.billAmount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      doc: doc, // Pass raw string if available, or null to lazy-load
      parsedDocMap: Map.unmodifiable(updatedDoc), // ✅ Freeze map
      billNumber: billNumber ?? this.billNumber,
      labNumber: labNumber ?? this.labNumber,
      visible: visible ?? this.visible,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
    );
  }

  // Getters
  String get salutation {
    final name = parsedDocMap['name'] ?? '';
    return name.toString().split('.').first;
  }

  String get freeText => parsedDocMap['free_text'] ?? '';
  bool get vip => (parsedDocMap['vip_client'] ?? 0) == 1;
  bool get urgent => (parsedDocMap['urgent'] ?? 0) == 1;
  int get credit => parsedDocMap['credit'] ?? 0;
  Map<String, dynamic> get settings => parsedDocMap['settings'] ?? {};
  bool get sendSms => (settings['send_sms'] ?? 1) == 1;
  bool get sendWhatsapp => (settings['send_whatsapp'] ?? 1) == 1;
  bool get sendEmail => (settings['send_email'] ?? 1) == 1;

  String get mobile => parsedDocMap['mobile'] ?? '';
  String get email => parsedDocMap['email'] ?? '';
  String get address => parsedDocMap['address'] ?? '';
  String get age => parsedDocMap['age'] ?? '';
  String get gender => parsedDocMap['gender'] ?? '';
  String get pincode => parsedDocMap['pincode'] ?? '';

  List<dynamic> get testItems => parsedDocMap['test_items'] ?? [];
  List<dynamic> get timeLine => parsedDocMap['time_line'] ?? [];
  Map<String, dynamic> get process => parsedDocMap['process'] ?? {};

  String get firstStep => process['first_step'] ?? '';
  String get prescriptionPath => process['fifth_step'] ?? '';
  String get proformaPath => process['second_step'] ?? '';

  // Factory for DB Row
  factory WorkOrder.fromRow(Map<String, dynamic> row) {
    try {
      final parsedId = _parseString(row, 'id');
      final parsedDocString = _parseString(row, 'doc');

      // Parse once here (in Isolate)
      final Map<String, dynamic> parsedMap = jsonDecode(parsedDocString);

      return WorkOrder(
        id: parsedId,
        tenantId: _parseNullableInt(row, 'tenant_id'),
        hcpmId: _parseNullableInt(row, 'hcpm_id'),
        docId: _parseString(row, 'doc_id'),
        patientName: _parseString(row, 'patient_name'),
        visitDate: _parseDateTime(row, 'visit_date'),
        visitTime: _parseString(row, 'visit_time'),
        doctorName: _parseString(row, 'doctor_name'),
        proId: _parseNullableInt(row, 'pro_id'),
        managerId: _parseNullableInt(row, 'manager_id'),
        managerName: _parseString(row, 'manager_name'),
        assignedId: _parseNullableInt(row, 'assigned_id'),
        assignedTo: _parseString(row, 'assigned_to'),
        b2bClientId: _parseNullableInt(row, 'b2b_client_id'),
        b2bClientName: _parseString(row, 'b2b_client_name'),
        status: _parseString(row, 'status'),
        serverStatus: _parseString(row, 'server_status'),
        billAmount: _parseDouble(row, 'bill_amount'),
        receivedAmount: _parseDouble(row, 'received_amount'),
        discountAmount: _parseDouble(row, 'discount_amount'),
        doc: parsedDocString,
        parsedDocMap: Map.unmodifiable(parsedMap), // ✅ Immutable
        billNumber: _parseString(row, 'bill_number'),
        labNumber: _parseString(row, 'lab_number'),
        visible: _parseBool(row, 'visible'),
        createdBy: _parseString(row, 'created_by'),
        createdAt: _parseDateTime(row, 'created_at'),
        lastUpdatedBy: _parseString(row, 'last_updated_by'),
        lastUpdatedAt: _parseDateTime(row, 'last_updated_at'),
      );
    } catch (e) {
      debugPrint('❌ WorkOrder Parsing Error: $e');
      rethrow;
    }
  }

  // Factory for Form Data
  factory WorkOrder.fromFormData({
    required String patientName,
    required String mobile,
    required String address,
    required DateTime visitDate,
    required String visitTime,
    required int managerId,
    required String managerName,
    required int tenantId,
    String? salutation,
    String? age,
    String? gender,
    String? email,
    String? pincode,
    String? doctorName,
    String? freeText,
    String? prescriptionPath,
    int? b2bClientId,
    String? b2bClientName,
    bool? vip,
    bool? urgent,
    int? credit,
    bool? sendSms,
    bool? sendWhatsapp,
    bool? sendEmail,
  }) {
    final appointmentDate = DateFormat('dd-MM-yyyy').format(visitDate);
    final docId = 'work_order:$appointmentDate:${const Uuid().v4()}';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();
    final createdEntry = '$appointmentDate | $managerName | Work Order Created';

    final initialDocMap = {
      '_id': docId,
      'mobile': mobile,
      'address': address,
      'age': age ?? 'NA',
      'gender': gender ?? 'Male',
      'email': email ?? 'NA',
      'pincode': pincode ?? '',
      'doctor_name': doctorName ?? '',
      'free_text': freeText ?? '',
      'pres_photo': prescriptionPath ?? '',
      'b2b_client_id': b2bClientId ?? 0,
      'b2b_client_name': b2bClientName ?? '',
      'vip_client': vip == true ? 1 : 0,
      'urgent': urgent == true ? 1 : 0,
      'credit': credit ?? 0,
      'process': {
        'first_step': '',
        'second_step': '',
        'third_step': '',
        'fourth_step': '',
        'fifth_step': prescriptionPath ?? '',
        'prescription_uploaded_at':
            prescriptionPath?.isNotEmpty == true ? now : '',
        'proforma_uploaded_at': '',
      },
      'settings': {
        'send_sms': sendSms == true ? 1 : 0,
        'send_whatsapp': sendWhatsapp == true ? 1 : 0,
        'send_email': sendEmail == true ? 1 : 0,
      },
      'time_line': [createdEntry],
      'test_items': [],
    };

    return WorkOrder(
      id: id,
      tenantId: tenantId,
      hcpmId: null,
      docId: docId,
      patientName: patientName,
      visitDate: visitDate,
      visitTime: visitTime,
      doctorName: doctorName ?? '',
      proId: null,
      managerId: managerId,
      managerName: managerName,
      assignedId: null,
      assignedTo: '',
      b2bClientId: b2bClientId,
      b2bClientName: b2bClientName ?? '',
      status: 'unassigned',
      serverStatus: 'waiting',
      billAmount: 0.0,
      receivedAmount: 0.0,
      discountAmount: 0.0,
      doc: jsonEncode(initialDocMap),
      parsedDocMap: Map.unmodifiable(initialDocMap),
      billNumber: '',
      labNumber: '',
      visible: true,
      createdBy: managerName,
      createdAt: DateTime.now(),
      lastUpdatedBy: managerName,
      lastUpdatedAt: DateTime.now(),
    );
  }

  static int _parseInt(Map<String, dynamic> row, String key) =>
      int.tryParse(row[key]?.toString() ?? '0') ?? 0;
  static int? _parseNullableInt(Map<String, dynamic> row, String key) =>
      int.tryParse(row[key]?.toString() ?? '');
  static double _parseDouble(Map<String, dynamic> row, String key) =>
      double.tryParse(row[key]?.toString() ?? '0.0') ?? 0.0;
  static String _parseString(Map<String, dynamic> row, String key) =>
      row[key]?.toString() ?? '';
  static bool _parseBool(Map<String, dynamic> row, String key) =>
      row[key] == 1 ||
      row[key] == true ||
      row[key].toString().toLowerCase() == 'true';
  static DateTime _parseDateTime(Map<String, dynamic> row, String key) {
    final val = row[key]?.toString();
    return val != null
        ? DateTime.tryParse(val) ?? DateTime.now()
        : DateTime.now();
  }
}

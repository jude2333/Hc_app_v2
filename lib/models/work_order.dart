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

// Sentinel value to distinguish "not provided" from "intentionally null"
// in copyWith. Dart's null can't serve both purposes for nullable fields.
const _sentinel = Object();

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

  // Marketing
  final String marketingPersonName;
  final String marketingPersonNumber;

  // Status
  final String status;
  final String serverStatus;

  // Financial
  final double billAmount;
  final double receivedAmount;
  final double discountAmount;

  // Full Document (Lazy Loaded)
  final String? _rawDocString;

  //  OPTIMIZATION 1: The Immutable Source of Truth for nested data
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

  // Sync Window - whether this record is within the sync date range
  final bool syncWindow;

  //  PRE-CACHED FORMATTED STRINGS (computed once at construction)
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
    required this.marketingPersonName,
    required this.marketingPersonNumber,
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
    required this.syncWindow,
    required this.formattedVisitDate,
    required this.formattedShortDate,
    required this.formattedBillAmount,
    required this.formattedReceivedAmount,
    required this.formattedDiscountAmount,
    required this.searchableText,
  }) : _rawDocString = doc;

  //  Factory constructor that pre-computes formatted strings
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
    required String marketingPersonName,
    required String marketingPersonNumber,
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
    bool syncWindow = true, // New work orders are always in sync window
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
      marketingPersonName: marketingPersonName,
      marketingPersonNumber: marketingPersonNumber,
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
      syncWindow: syncWindow,
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

  //  COMPATIBILITY GETTER (Prevents errors in other files)
  Map<String, dynamic> get parsedDoc => parsedDocMap;

  // Lazy doc getter
  String get doc => _rawDocString ?? jsonEncode(parsedDocMap);

  //  OPTIMIZATION 4: Robust Equality Check
  // @override
  // bool operator ==(Object other) {
  //   if (identical(this, other)) return true;

  //   return other is WorkOrder &&
  //       other.id == id &&
  //       // Normalize time to seconds to avoid millisecond redraws
  //       other.lastUpdatedAt.millisecondsSinceEpoch ~/ 1000 ==
  //           lastUpdatedAt.millisecondsSinceEpoch ~/ 1000 &&
  //       other.status == status &&
  //       other.serverStatus == serverStatus &&
  //       other.assignedId == assignedId &&
  //       // Normalize doubles to avoid micro-precision diffs
  //       (other.billAmount - billAmount).abs() < 0.01 &&
  //       (other.receivedAmount - receivedAmount).abs() < 0.01;
  // }

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
      'marketing_person_name': marketingPersonName,
      'marketing_person_number': marketingPersonNumber,
      'alternate_mobile': parsedDocMap['alternate_mobile'] ?? '',
      'client_code': parsedDocMap['client_code'] ?? '',
      'doctor_code': parsedDocMap['doctor_code'] ?? '',
      'vip_client': parsedDocMap['vip_client'] ?? 0,
      'urgent': parsedDocMap['urgent'] ?? 0,
      'cghs_client': parsedDocMap['cghs_client'] ?? 0,
      'credit': parsedDocMap['credit'] ?? 0,
      'appointment_date': DateFormat('dd-MM-yyyy').format(visitDate),
      'appointment_time': visitTime,
      'pres_photo': parsedDocMap['pres_photo'] ?? '',
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
      'doc': buildDoc(), // Raw Map — PostgREST handles jsonb encoding
      'bill_number': billNumber,
      'lab_number': labNumber,
      'visible': visible ? 1 : 0,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'last_updated_by': lastUpdatedBy,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
      'sync_window': syncWindow ? 1 : 0,
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
    Object? assignedId = _sentinel,
    String? assignedTo,
    int? b2bClientId,
    String? b2bClientName,
    String? marketingPersonName,
    String? marketingPersonNumber,
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
    bool? cghsClient,
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
    String? alternateMobile,
    String? clientCode,
    String? doctorCode,
  }) {
    // Resolve sentinel for assignedId: _sentinel means "keep existing"
    final int? resolvedAssignedId = identical(assignedId, _sentinel)
        ? this.assignedId
        : assignedId as int?;

    //  OPTIMIZATION 5: Deep Copy to break references
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
    if (marketingPersonName != null) {
      updatedDoc['marketing_person_name'] = marketingPersonName;
    }
    if (marketingPersonNumber != null) {
      updatedDoc['marketing_person_number'] = marketingPersonNumber;
    }
    if (alternateMobile != null) {
      updatedDoc['alternate_mobile'] = alternateMobile;
    }
    if (clientCode != null) updatedDoc['client_code'] = clientCode;
    if (doctorCode != null) updatedDoc['doctor_code'] = doctorCode;
    if (status != null) updatedDoc['status'] = status;
    if (serverStatus != null) updatedDoc['server_status'] = serverStatus;
    if (!identical(assignedId, _sentinel)) updatedDoc['assigned_id'] = resolvedAssignedId;
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
    if (cghsClient != null) updatedDoc['cghs_client'] = cghsClient ? 1 : 0;
    if (credit != null) updatedDoc['credit'] = credit;
    if (prescriptionPath != null) updatedDoc['pres_photo'] = prescriptionPath;
    if (oldId != null) updatedDoc['old_id'] = oldId;
    if (sortTime != null) updatedDoc['sort_time'] = sortTime;

    if (process != null) {
      updatedDoc['process'] = process;
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
      assignedId: resolvedAssignedId,
      assignedTo: assignedTo ?? this.assignedTo,
      b2bClientId: b2bClientId ?? this.b2bClientId,
      b2bClientName: b2bClientName ?? this.b2bClientName,
      marketingPersonName: marketingPersonName ?? this.marketingPersonName,
      marketingPersonNumber:
          marketingPersonNumber ?? this.marketingPersonNumber,
      status: status ?? this.status,
      serverStatus: serverStatus ?? this.serverStatus,
      billAmount: billAmount ?? this.billAmount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      doc: doc, // Pass raw string if available, or null to lazy-load
      parsedDocMap: Map.unmodifiable(updatedDoc), //  Freeze map
      billNumber: billNumber ?? this.billNumber,
      labNumber: labNumber ?? this.labNumber,
      visible: visible ?? this.visible,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      syncWindow: this.syncWindow, // Preserve sync_window on edit
    );
  }

  // Getters
  String get salutation {
    final name = parsedDocMap['name'] ?? '';
    return name.toString().split('.').first;
  }

  String get freeText => parsedDocMap['free_text'] ?? '';
  bool get vip {
    final val = parsedDocMap['vip_client'];
    if (val is bool) return val;
    return val == 1;
  }

  bool get urgent {
    final val = parsedDocMap['urgent'];
    if (val is bool) return val;
    return val == 1;
  }

  bool get cghsClient {
    final val = parsedDocMap['cghs_client'];
    if (val is bool) return val;
    return val == 1;
  }

  int get credit {
    final val = parsedDocMap['credit'];
    if (val is bool) return val ? 1 : 0;
    if (val is int) return val;
    return int.tryParse(val?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> get settings => parsedDocMap['settings'] ?? {};
  bool get sendSms => (settings['send_sms'] ?? 1) == 1;
  bool get sendWhatsapp => (settings['send_whatsapp'] ?? 1) == 1;
  bool get sendEmail => (settings['send_email'] ?? 1) == 1;

  String get mobile => parsedDocMap['mobile'] ?? '';
  String get alternateMobile => parsedDocMap['alternate_mobile'] ?? '';
  String get email => parsedDocMap['email'] ?? '';
  String get address => parsedDocMap['address'] ?? '';
  String get age => parsedDocMap['age'] ?? '';
  String get gender => parsedDocMap['gender'] ?? '';
  String get pincode => parsedDocMap['pincode'] ?? '';
  String get clientCode => parsedDocMap['client_code'] ?? '';
  String get doctorCode => parsedDocMap['doctor_code'] ?? '';

  List<dynamic> get testItems => parsedDocMap['test_items'] ?? [];
  List<dynamic> get timeLine => parsedDocMap['time_line'] ?? [];
  Map<String, dynamic> get process => parsedDocMap['process'] ?? {};

  String get firstStep => process['first_step'] ?? '';
  String get prescriptionPath => process['fifth_step'] ?? '';
  String get proformaPath => process['second_step'] ?? '';
  String get prescriptionPhoto => parsedDocMap['pres_photo'] ?? '';

  // Sent status for billing send functionality
  String get sentStatus => parsedDocMap['sent_status']?.toString() ?? '';

  // Amount received for send API
  String get amountReceived =>
      parsedDocMap['amount_received']?.toString() ?? '0';
  String get remarks => parsedDocMap['remarks']?.toString() ?? '';

  /// Calculated total: uses doc 'total' field, or sums test_items base_cost
  double get calculatedTotal {
    // First try the document's 'total' field
    final docTotal = parsedDocMap['total'];
    if (docTotal != null) {
      if (docTotal is num && docTotal > 0) return docTotal.toDouble();
      final parsed = double.tryParse(docTotal.toString());
      if (parsed != null && parsed > 0) return parsed;
    }

    // Fallback: sum test_items base_cost
    final items = testItems;
    if (items.isNotEmpty) {
      return items.fold<double>(0, (sum, item) {
        final cost = item['base_cost'];
        if (cost is num) return sum + cost.toDouble();
        return sum + (double.tryParse(cost?.toString() ?? '0') ?? 0);
      });
    }

    // Final fallback to billAmount field
    return billAmount;
  }

  /// Formatted calculated total for display
  String get formattedCalculatedTotal =>
      _currencyFormat.format(calculatedTotal);

  // Factory for DB Row
  factory WorkOrder.fromRow(Map<String, dynamic> row) {
    try {
      final parsedId = _parseString(row, 'id');
      final parsedDocString = _parseString(row, 'doc');

      // Parse once here (in Isolate)
      // Handle both: plain JSON string (text era) and double-encoded (jsonb transition)
      dynamic decoded = jsonDecode(parsedDocString);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      final Map<String, dynamic> parsedMap = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);

      return WorkOrder(
        id: parsedId,
        tenantId: _parseNullableInt(row, 'tenant_id'),
        hcpmId: _parseNullableInt(row, 'hcpm_id'),
        docId: _parseString(row, 'doc_id'),
        // Prefer doc 'name' (has salutation e.g. "Mr. John") over row-level
        // patient_name (backup service strips titles via cleanUpName)
        patientName: (parsedMap['name']?.toString().isNotEmpty == true)
            ? parsedMap['name'].toString()
            : _parseString(row, 'patient_name'),
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
        marketingPersonName:
            parsedMap['marketing_person_name']?.toString() ?? '',
        marketingPersonNumber:
            parsedMap['marketing_person_number']?.toString() ?? '',
        status: _parseString(row, 'status'),
        serverStatus: _parseString(row, 'server_status'),
        billAmount: _parseDouble(row, 'bill_amount'),
        receivedAmount: _parseDouble(row, 'received_amount'),
        discountAmount: _parseDouble(row, 'discount_amount'),
        doc: parsedDocString,
        parsedDocMap: Map.unmodifiable(parsedMap), //  Immutable
        billNumber: _parseString(row, 'bill_number'),
        labNumber: _parseString(row, 'lab_number'),
        visible: _parseBool(row, 'visible'),
        createdBy: _parseString(row, 'created_by'),
        createdAt: _parseDateTime(row, 'created_at'),
        lastUpdatedBy: _parseString(row, 'last_updated_by'),
        lastUpdatedAt: _parseDateTime(row, 'last_updated_at'),
        syncWindow: _parseBool(row, 'sync_window'),
      );
    } catch (e) {
      debugPrint(' WorkOrder Parsing Error: $e');
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
    List<String>? prescriptionPaths,
    int? b2bClientId,
    String? b2bClientName,
    String? marketingPersonName,
    String? marketingPersonNumber,
    String? alternateMobile,
    String? clientCode,
    String? doctorCode,
    bool? vip,
    bool? urgent,
    bool? cghsClient,
    int? credit,
    bool? sendSms,
    bool? sendWhatsapp,
    bool? sendEmail,
  }) {
    final appointmentDate = DateFormat('dd-MM-yyyy').format(visitDate);
    final docId = 'work_order:$appointmentDate:${const Uuid().v4()}';
    // Use doc_id as the PowerSync id — matches sync rules (doc_id as id)
    final id = docId;

    final createdEntry = '$appointmentDate | $managerName | Work Order Created';

    final prescriptionJoined =
        (prescriptionPaths != null && prescriptionPaths.isNotEmpty)
            ? prescriptionPaths.join(',')
            : '';

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
      'pres_photo': prescriptionJoined,
      'b2b_client_id': b2bClientId ?? 0,
      'b2b_client_name': b2bClientName ?? '',
      'marketing_person_name': marketingPersonName ?? '',
      'marketing_person_number': marketingPersonNumber ?? '',
      'alternate_mobile': alternateMobile ?? '',
      'client_code': clientCode ?? '',
      'doctor_code': doctorCode ?? '',
      'vip_client': vip == true ? 1 : 0,
      'urgent': urgent == true ? 1 : 0,
      'cghs_client': cghsClient == true ? 1 : 0,
      'credit': credit ?? 0,
      'process': {
        'first_step': '',
        'second_step': '',
        'third_step': '',
        'fourth_step': '',
        'fifth_step': '',
        'prescription_uploaded_at': '',
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
      marketingPersonName: marketingPersonName ?? '',
      marketingPersonNumber: marketingPersonNumber ?? '',
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

  factory WorkOrder.fromDocMap(Map<String, dynamic> docMap) {
    // Parse appointment_date which is in dd-MM-yyyy format
    DateTime visitDate = DateTime.now();
    final dateStr = docMap['appointment_date']?.toString() ?? '';
    if (dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // yyyy-MM-dd format
            visitDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            // dd-MM-yyyy format
            visitDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        }
      } catch (e) {
        debugPrint('Error parsing date in fromDocMap: $e');
      }
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final docId = docMap['_id']?.toString() ??
        'search_copy:${DateTime.now().millisecondsSinceEpoch}';

    // Parse numeric fields
    int? b2bClientId;
    final b2bVal = docMap['b2b_client_id'];
    if (b2bVal != null && b2bVal != 0 && b2bVal != '') {
      b2bClientId = int.tryParse(b2bVal.toString());
    }

    int? assignedId;
    final assignedVal = docMap['assigned_id'];
    if (assignedVal != null && assignedVal != 0 && assignedVal != '') {
      assignedId = int.tryParse(assignedVal.toString());
    }

    int? managerId;
    final managerVal = docMap['manager_id'];
    if (managerVal != null && managerVal != '' && managerVal != 0) {
      managerId = int.tryParse(managerVal.toString());
    }

    int? tenantId;
    final tenantVal = docMap['tenant_id'];
    if (tenantVal != null && tenantVal != '' && tenantVal != 0) {
      tenantId = int.tryParse(tenantVal.toString());
    }

    // Parse amounts
    double billAmount = 0.0;
    final totalVal = docMap['total'];
    if (totalVal != null) {
      billAmount = double.tryParse(totalVal.toString()) ?? 0.0;
    }

    double receivedAmount = 0.0;
    final receivedVal = docMap['amount_received'];
    if (receivedVal != null) {
      receivedAmount = double.tryParse(receivedVal.toString()) ?? 0.0;
    }

    double discountAmount = 0.0;
    final discountVal = docMap['discount'];
    if (discountVal != null) {
      discountAmount = double.tryParse(discountVal.toString()) ?? 0.0;
    }

    // Build a proper docMap with all required fields
    final fullDocMap = Map<String, dynamic>.from(docMap);

    return WorkOrder(
      id: id,
      tenantId: tenantId,
      hcpmId: null,
      docId: docId,
      patientName: docMap['name']?.toString() ?? '',
      visitDate: visitDate,
      visitTime: docMap['appointment_time']?.toString() ?? '',
      doctorName: docMap['doctor_name']?.toString() ?? '',
      proId: null,
      managerId: managerId,
      managerName: docMap['manager_name']?.toString() ?? '',
      assignedId: assignedId,
      assignedTo: docMap['assigned_to']?.toString() ?? '',
      b2bClientId: b2bClientId,
      b2bClientName: docMap['b2b_client_name']?.toString() ?? '',
      marketingPersonName: docMap['marketing_person_name']?.toString() ?? '',
      marketingPersonNumber:
          docMap['marketing_person_number']?.toString() ?? '',
      status: docMap['status']?.toString() ?? 'unassigned',
      serverStatus: docMap['server_status']?.toString() ?? 'waiting',
      billAmount: billAmount,
      receivedAmount: receivedAmount,
      discountAmount: discountAmount,
      doc: jsonEncode(fullDocMap),
      parsedDocMap: Map.unmodifiable(fullDocMap),
      billNumber: docMap['bill_number']?.toString() ?? '',
      labNumber: docMap['lab_number']?.toString() ?? '',
      visible: true,
      createdBy: docMap['manager_name']?.toString() ?? '',
      createdAt: DateTime.now(),
      lastUpdatedBy: docMap['manager_name']?.toString() ?? '',
      lastUpdatedAt: DateTime.now(),
    );
  }
}

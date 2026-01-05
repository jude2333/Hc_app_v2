// lib/models/new_work_order.dart
import 'dart:convert';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:uuid/uuid.dart';

class NewWorkOrder {
  // Generated fields
  final String id;
  final String docId;
  final int sortTime;

  // Required fields
  final String patientName;
  final String mobile;
  final String address;
  final String appointmentDate; // dd-MM-yyyy format
  final String appointmentTime; // HH:mm format

  // Optional fields
  final String salutation;
  final String age;
  final String gender;
  final String email;
  final String pincode;
  final String doctorName;
  final String freeText;
  final String prescriptionPath;

  // Assignment
  final int managerId;
  final String managerName;
  final int tenantId;

  // Technician assignment
  final int assignedId;
  final String assignedTo;

  // B2B
  final int b2bClientId;
  final String b2bClientName;

  // Flags
  final int vipClient; // 0 or 1
  final int urgent; // 0 or 1
  final int credit; // 0=None, 1=Credit, 2=Trial

  // Settings
  final int sendSms;
  final int sendWhatsapp;
  final int sendEmail;

  // Status
  final String status;
  final String serverStatus;

  NewWorkOrder({
    String? id,
    String? docId,
    int? sortTime,
    required this.patientName,
    required this.mobile,
    required this.address,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.managerId,
    required this.managerName,
    required this.tenantId,
    this.salutation = 'Mr',
    this.age = 'NA',
    this.gender = 'Male',
    this.email = 'NA',
    this.pincode = '',
    this.doctorName = '',
    this.freeText = '',
    this.prescriptionPath = '',
    this.b2bClientId = 0,
    this.b2bClientName = '',
    this.vipClient = 0,
    this.urgent = 0,
    this.credit = 0,
    this.sendSms = 1,
    this.sendWhatsapp = 1,
    this.sendEmail = 1,
    this.status = 'unassigned',
    this.serverStatus = 'waiting',
    this.assignedId = 0,
    this.assignedTo = '',
  })  : id = id ?? _generateLocalId(),
        docId = _generateDocId(appointmentDate),
        sortTime = _calculateSortTime(appointmentDate, appointmentTime);

  // ==========================
  // COPYWITH METHOD
  // ==========================
  NewWorkOrder copyWith({
    String? id,
    String? docId,
    int? sortTime,
    String? patientName,
    String? mobile,
    String? address,
    String? appointmentDate,
    String? appointmentTime,
    String? salutation,
    String? age,
    String? gender,
    String? email,
    String? pincode,
    String? doctorName,
    String? freeText,
    String? prescriptionPath,
    int? managerId,
    String? managerName,
    int? tenantId,
    int? assignedId,
    String? assignedTo,
    int? b2bClientId,
    String? b2bClientName,
    int? vipClient,
    int? urgent,
    int? credit,
    int? sendSms,
    int? sendWhatsapp,
    int? sendEmail,
    String? status,
    String? serverStatus,
  }) {
    return NewWorkOrder(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      sortTime: sortTime ?? this.sortTime,
      patientName: patientName ?? this.patientName,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      tenantId: tenantId ?? this.tenantId,
      salutation: salutation ?? this.salutation,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      pincode: pincode ?? this.pincode,
      doctorName: doctorName ?? this.doctorName,
      freeText: freeText ?? this.freeText,
      prescriptionPath: prescriptionPath ?? this.prescriptionPath,
      b2bClientId: b2bClientId ?? this.b2bClientId,
      b2bClientName: b2bClientName ?? this.b2bClientName,
      vipClient: vipClient ?? this.vipClient,
      urgent: urgent ?? this.urgent,
      credit: credit ?? this.credit,
      sendSms: sendSms ?? this.sendSms,
      sendWhatsapp: sendWhatsapp ?? this.sendWhatsapp,
      sendEmail: sendEmail ?? this.sendEmail,
      status: status ?? this.status,
      serverStatus: serverStatus ?? this.serverStatus,
      assignedId: assignedId ?? this.assignedId,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }

  factory NewWorkOrder.fromMap(Map<String, dynamic> map) {
    // Parse doc JSON to get additional fields
    Map<String, dynamic> docData = {};
    if (map['doc'] != null && map['doc'] is String) {
      try {
        docData = jsonDecode(map['doc'] as String);
      } catch (e) {
        // If doc isn't valid JSON, continue with empty docData
      }
    }

    return NewWorkOrder(
      id: (map['id'] ?? '').toString(), // ✅ Extract database ID
      docId: map['doc_id'] ?? map['_id'] ?? '',
      patientName: map['patient_name'] ?? map['name'] ?? '',
      mobile: docData['mobile'] ?? map['mobile'] ?? '',
      address: docData['address'] ?? map['address'] ?? '',
      appointmentDate:
          docData['appointment_date'] ?? map['appointment_date'] ?? '',
      appointmentTime: map['visit_time'] ?? map['appointment_time'] ?? '',
      managerId: int.tryParse((map['manager_id'] ?? 0).toString()) ?? 0,
      managerName: map['manager_name'] ?? '',
      tenantId: int.tryParse((map['tenant_id'] ?? 0).toString()) ?? 0,
      salutation: docData['salutation'] ?? 'Mr',
      age: docData['age'] ?? map['age'] ?? 'NA',
      gender: docData['gender'] ?? map['gender'] ?? 'Male',
      email: docData['email'] ?? map['email'] ?? 'NA',
      pincode: docData['pincode'] ?? map['pincode'] ?? '',
      doctorName: map['doctor_name'] ?? docData['doctor_name'] ?? '',
      freeText: docData['free_text'] ?? map['free_text'] ?? '',
      prescriptionPath: docData['pres_photo'] ?? map['pres_photo'] ?? '',
      b2bClientId: int.tryParse((map['b2b_client_id'] ?? 0).toString()) ?? 0,
      b2bClientName: map['b2b_client_name'] ?? '',
      vipClient: (docData['vip_client'] ?? map['vip_client']) == true ||
              (docData['vip_client'] ?? map['vip_client']) == 1
          ? 1
          : 0,
      urgent: (docData['urgent'] ?? map['urgent']) == true ||
              (docData['urgent'] ?? map['urgent']) == 1
          ? 1
          : 0,
      credit:
          int.tryParse((docData['credit'] ?? map['credit'] ?? 0).toString()) ??
              0,
      sendSms: 1,
      sendWhatsapp: 1,
      sendEmail: 1,
      status: map['status'] ?? 'unassigned',
      serverStatus: map['server_status'] ?? 'waiting',
      assignedId: int.tryParse((map['assigned_id'] ?? 0).toString()) ?? 0,
      assignedTo: map['assigned_to'] ?? '',
    );
  }

  // ==========================
  // HELPERS
  // ==========================

  static String _generateDocId(String appointmentDate) {
    final parts = appointmentDate.split('-');
    final isoDate = '${parts[2]}-${parts[1]}-${parts[0]}';
    return 'work_order:$isoDate:${const Uuid().v4()}';
  }

  static String _generateLocalId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static int _calculateSortTime(
      String appointmentDate, String appointmentTime) {
    try {
      final parts = appointmentDate.split('-');
      final timeParts = appointmentTime.split(':');

      final dateTime = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      return dateTime.millisecondsSinceEpoch;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  // ==========================
  // DOCUMENT BUILDING
  // ==========================

  Map<String, dynamic> buildDoc() {
    final now = DateTime.now().toIso8601String();
// In new_work_order.dart - buildDoc() method
    final createdEntry = '$appointmentDate | $managerName | Work Order Created';

    return {
      '_id': docId,
      'old_id': '',
      'name': patientName,
      'age': age,
      'gender': gender,
      'address': address,
      'email': email,
      'pincode': pincode,
      'mobile': mobile,
      'doctor_name': doctorName,
      'pro_id': '',
      'b2b_client_id': b2bClientId,
      'b2b_client_name': b2bClientName,
      'vip_client': vipClient,
      'urgent': urgent,
      'credit': credit,
      'appointment_date': appointmentDate,
      'appointment_time': appointmentTime,
      'pres_photo': prescriptionPath,
      'status': status,
      'server_status': serverStatus,
      'assigned_to': assignedTo,
      'assigned_id': assignedId,
      'free_text': freeText,
      'process': {
        'first_step': '',
        'second_step': '',
        'third_step': '',
        'fourth_step': '',
        'fifth_step': prescriptionPath,
        'prescription_uploaded_at': prescriptionPath.isNotEmpty ? now : '',
        'proforma_uploaded_at': '',
      },
      'settings': {
        'send_sms': sendSms,
        'send_whatsapp': sendWhatsapp,
        'send_email': sendEmail,
      },
      'updated_at': now,
      'sort_time': sortTime,
      'manager_id': managerId.toString(),
      'manager_name': managerName,
      'tenant_id': tenantId.toString(),
      'time_line': [createdEntry],
      'test_items': [],
      'total': 0,
      'amount_received': '',
      'discount': '0',
      'hc_charges': '0',
      'disposable_charges': '0',
      'payment_method': '',
      'gpay_ref': '',
      'bill_number': '',
      'lab_number': '',
      'remarks': '',
    };
  }

  Map<String, dynamic> toInsertJson() {
    final docJson = jsonEncode(buildDoc());
    final now = DateTime.now().toIso8601String();

    return {
      'id': id,
      'tenant_id': tenantId,
      'hcpm_id': null,
      'doc_id': docId,
      'patient_name': patientName,
      'visit_date': _convertToIsoDate(appointmentDate),
      'visit_time': appointmentTime,
      'doctor_name': doctorName,
      'pro_id': 0,
      'manager_id': managerId,
      'manager_name': managerName,
      'assigned_id': assignedId,
      'assigned_to': assignedTo,
      'b2b_client_id': b2bClientId,
      'b2b_client_name': b2bClientName,
      'status': status,
      'server_status': serverStatus,
      'bill_amount': 0.0,
      'received_amount': 0.0,
      'discount_amount': 0.0,
      'doc': docJson,
      'bill_number': '',
      'lab_number': '',
      'visible': 1,
      'created_by': managerName,
      'created_at': now,
      'last_updated_by': managerName,
      'last_updated_at': now,
    };
  }

  Map<String, dynamic> toUpdateJson(Map<String, dynamic> customDoc) {
    final docJson = jsonEncode(customDoc);
    final now = DateTime.now().toIso8601String();

    return {
      'id': id,
      'tenant_id': tenantId,
      'doc_id': docId,
      'patient_name': patientName,
      'visit_date': _convertToIsoDate(appointmentDate),
      'visit_time': appointmentTime,
      'assigned_id': assignedId,
      'assigned_to': assignedTo,
      'status': status,
      'server_status': serverStatus,
      'doc': docJson,
      'last_updated_by': managerName,
      'last_updated_at': now,
    };
  }

  static String _convertToIsoDate(String ddmmyyyy) {
    final parts = ddmmyyyy.split('-');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }
}

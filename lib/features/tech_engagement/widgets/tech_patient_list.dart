import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/providers/tech_engagement_provider.dart';
import 'tech_shared_widgets.dart';

class TechPatientList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const TechPatientList({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 900,
                child: Column(
                  children: _buildTableContent(orders),
                ),
              ),
            );
          } else {
            return Column(
              children: _buildTableContent(orders),
            );
          }
        },
      ),
    );
  }

  List<Widget> _buildTableContent(List<Map<String, dynamic>> orders) {
    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          children: [
            TechHeaderCell("Patient", flex: 2),
            TechHeaderCell("Gender", flex: 1),
            TechHeaderCell("Age", flex: 1),
            TechHeaderCell("Mobile", flex: 2),
            TechHeaderCell("Time", flex: 1),
            TechHeaderCell("Status", flex: 1, align: TextAlign.center),
            TechHeaderCell("HC", flex: 1),
            TechHeaderCell("Amt", flex: 1),
            TechHeaderCell("Remit", flex: 1, align: TextAlign.center),
          ],
        ),
      ),
      const SizedBox(height: 4),
      ...orders.map((order) => TechPatientRow(order: order)).toList(),
    ];
  }
}

class TechPatientRow extends ConsumerWidget {
  final Map<String, dynamic> order;
  const TechPatientRow({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(techEngagementProvider);
    final doc = _parseDoc(order['doc']);
    final accepted = doc['accept_remittance'] == true;
    final amount =
        double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0;
    final paymentMethod = doc['payment_method']?.toString() ?? 'cash';
    final isCash = paymentMethod == 'cash' && amount > 0;
    final hcCharges = doc['hc_charges']?.toString() ?? '0';
    final status = order['status'] ?? '';
    final isFinished = status == 'Finished';
    final gpayRef = doc['gpay_ref']?.toString() ?? '';

    String timeOrDate = order['visit_time']?.toString() ?? '';
    if (state.isMonthWise) {
      final visitDate =
          DateTime.tryParse(order['visit_date']?.toString() ?? '');
      if (visitDate != null) {
        timeOrDate =
            "${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}-${visitDate.day.toString().padLeft(2, '0')}";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          TechDataCell(order['patient_name'] ?? '', flex: 2),
          TechDataCell(doc['gender']?.toString() ?? '', flex: 1),
          TechDataCell(doc['age']?.toString() ?? '', flex: 1),
          TechDataCell(doc['mobile']?.toString() ?? '', flex: 2),
          TechDataCell(timeOrDate, flex: 1),
          Expanded(
            flex: 1,
            child: Center(
              child: EngagementStatusChip(status: status),
            ),
          ),
          TechDataCell(hcCharges, flex: 1),
          TechDataCell("${amount.toInt()}", flex: 1),
          Expanded(
            flex: 1,
            child: Center(
              child: _buildRemittanceCell(ref, isCash, isFinished,
                  paymentMethod, accepted, gpayRef, order),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemittanceCell(
      WidgetRef ref,
      bool isCash,
      bool isFinished,
      String paymentMethod,
      bool accepted,
      String gpayRef,
      Map<String, dynamic> order) {
    if (paymentMethod == 'gpay') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue),
        ),
        child: Text(
          "GPay $gpayRef",
          style: const TextStyle(fontSize: 10, color: Colors.blue),
          textAlign: TextAlign.center,
        ),
      );
    } else if (isCash && isFinished) {
      return RemittanceToggle(
        accepted: accepted,
        onToggle: () {
          ref
              .read(techEngagementProvider.notifier)
              .toggleRemittance(order['id'].toString(), accepted);
        },
      );
    } else {
      return const Text(
        "Credit Client",
        style: TextStyle(fontSize: 10, color: Colors.black54),
        textAlign: TextAlign.center,
      );
    }
  }

  Map<String, dynamic> _parseDoc(dynamic doc) {
    try {
      if (doc == null) return {};
      if (doc is Map) return Map<String, dynamic>.from(doc);
      if (doc is String) {
        if (doc.isEmpty) return {};
        return jsonDecode(doc) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error parsing doc in TechPatientRow: $e');
    }
    return {};
  }
}

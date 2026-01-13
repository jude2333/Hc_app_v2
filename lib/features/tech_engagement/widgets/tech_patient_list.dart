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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 700, // Fixed width for horizontal scroll
          child: Column(
            children: [
              // Inner Header - Light Orange
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
              // Patient Rows
              ...orders.map((order) => TechPatientRow(order: order)).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

class TechPatientRow extends ConsumerWidget {
  final Map<String, dynamic> order;
  const TechPatientRow({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = jsonDecode(order['doc'] ?? '{}');
    final accepted = doc['accept_remittance'] == true;
    final amount =
        double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0;
    final paymentMethod = doc['payment_method']?.toString() ?? 'cash';
    final isCash = paymentMethod == 'cash' && amount > 0;
    final hcCharges = doc['hc_charges']?.toString() ?? '0';
    final status = order['status'] ?? '';

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
          TechDataCell(order['patient_name'] ?? '', flex: 1),
          TechDataCell(doc['gender']?.toString() ?? '', flex: 1),
          TechDataCell(doc['age']?.toString() ?? '', flex: 1),
          TechDataCell(doc['mobile']?.toString() ?? '', flex: 1),
          TechDataCell(order['visit_time']?.toString() ?? '', flex: 1),
          // Status Chip (Compact)
          Expanded(
            flex: 1,
            child: Center(
              child: EngagementStatusChip(status: status),
            ),
          ),

          TechDataCell(hcCharges, flex: 1),
          TechDataCell("${amount.toInt()}", flex: 1),
          // Remittance Toggle (Compact)
          Expanded(
            flex: 1,
            child: Center(
              child: isCash
                  ? RemittanceToggle(
                      accepted: accepted,
                      onToggle: () {
                        ref
                            .read(techEngagementProvider.notifier)
                            .toggleRemittance(order['id'].toString(), accepted);
                      },
                    )
                  : Text(
                      paymentMethod == 'gpay' ? "GP" : "Cr",
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey.shade500),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

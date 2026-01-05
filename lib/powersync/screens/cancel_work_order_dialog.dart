import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

class CancelWorkOrderDialog extends ConsumerStatefulWidget {
  final WorkOrder workOrder;

  const CancelWorkOrderDialog({Key? key, required this.workOrder})
      : super(key: key);

  @override
  ConsumerState<CancelWorkOrderDialog> createState() =>
      _CancelWorkOrderDialogState();
}

class _CancelWorkOrderDialogState extends ConsumerState<CancelWorkOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _cancelOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final provider = ref.read(workOrderProvider);

      final currentUser =
          storage.getFromSession('logged_in_emp_name') ?? 'Technician';
      final now = DateTime.now();

      final timeString = DateFormat('dd-MM-yyyy').format(now);
      final timelineEntry = '$timeString | $currentUser | Work Order Cancelled';

      final updatedDocMap =
          Map<String, dynamic>.from(widget.workOrder.parsedDoc);

      updatedDocMap['status'] = 'cancelled';
      updatedDocMap['server_status'] = 'cancelled';
      updatedDocMap['cancel_reason'] = _reasonController.text.trim();
      updatedDocMap['updated_at'] = now.toIso8601String();

      List<dynamic> timeline = List.from(updatedDocMap['time_line'] ?? []);
      timeline.add(timelineEntry);
      updatedDocMap['time_line'] = timeline;

      final updatedWorkOrder = widget.workOrder.copyWith(
        status: 'cancelled',
        serverStatus: 'cancelled',
        lastUpdatedBy: currentUser,
        lastUpdatedAt: now,
        doc: jsonEncode(updatedDocMap),
      );

      final success = await provider.updateWorkOrder(updatedWorkOrder,
          customDoc: updatedDocMap);

      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      if (mounted) Navigator.of(context).pop(false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(24),
      title: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Cancel Work Order',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: isWeb ? 400 : width * 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel the order for ${widget.workOrder.patientName}?',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason For Cancellation',
                  hintText: 'Enter specific reason...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note, color: Colors.orange),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Reason is required';
                  if (v.trim().length < 5)
                    return 'Reason must be at least 5 characters.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('No, Keep Order',
              style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _cancelOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Yes, Cancel Order',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

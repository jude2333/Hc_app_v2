import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/com_center_provider.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/database/sms_template.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

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

      final currentUser = storage.getFromSession('logged_in_emp_name');
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
        if (widget.workOrder.assignedTo.isNotEmpty) {
          await _sendCancellationNotification();
        }

        Navigator.of(context).pop(true);

        if (widget.workOrder.assignedTo.isNotEmpty) {
          _showCancellationNotificationDialog();
        }
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

  Future<void> _sendCancellationNotification() async {
    try {
      final notificationDb = ref.read(notificationDbProvider);
      final wo = widget.workOrder;

      final msgHeader =
          "Cancelled Collection on ${DateFormat('dd-MM-yyyy').format(wo.visitDate)} ${wo.visitTime}.";
      final msgBody = "Cancelled home collection for ${wo.patientName}"
          "(${wo.age}/${wo.gender}) "
          "address:${wo.address} mobile:${wo.mobile} pincode:${wo.pincode}"
          " ${wo.freeText}";

      final result = await notificationDb.createNotification(
        toId: wo.assignedId ?? 0,
        toName: wo.assignedTo,
        msgHeader: msgHeader,
        msgBody: msgBody,
      );

      if (result == "OK") {
        debugPrint("✅ Cancellation notification sent to ${wo.assignedTo}");
      } else {
        debugPrint("⚠️ Failed to send cancellation notification: $result");
      }
    } catch (e) {
      debugPrint("❌ Error sending cancellation notification: $e");
    }
  }

  void _showCancellationNotificationDialog() {
    final wo = widget.workOrder;
    bool sendSms = true;
    bool sendWhatsApp = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: const Text('Cancelled Successfully',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Do you wish to inform ${wo.patientName} (Mob: ${wo.mobile}) about the cancellation?'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('SMS'),
                  value: sendSms,
                  onChanged: (v) => setState(() => sendSms = v ?? false),
                  dense: true,
                ),
                CheckboxListTile(
                  title: const Text('WhatsApp'),
                  value: sendWhatsApp,
                  onChanged: (v) => setState(() => sendWhatsApp = v ?? false),
                  dense: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);

                  if (Settings.development) {
                    debugPrint(
                        '⏭️ Skipping cancellation SMS (development mode)');
                    return;
                  }

                  await _sendCancellationMessages(
                      sendSms: sendSms, sendWhatsApp: sendWhatsApp);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendCancellationMessages(
      {required bool sendSms, required bool sendWhatsApp}) async {
    try {
      final storage = ref.read(storageServiceProvider);
      final comCenter = ref.read(comCenterProvider);
      final wo = widget.workOrder;

      final rescheduleUrl = '${Settings.msgUrl}reschedule';

      final baseMessage = {
        'center_id': storage.getFromSession('logged_in_tenant_id'),
        'center_name': storage.getFromSession('logged_in_tenant_name'),
        'department_id': storage.getFromSession('department_id'),
        'department_name': storage.getFromSession('department_name'),
        'role_id': storage.getFromSession('role_id'),
        'role_name': storage.getFromSession('role_name'),
        'emp_id': storage.getFromSession('logged_in_emp_id'),
        'emp_name': storage.getFromSession('logged_in_emp_name'),
        'recipient_mobile': wo.mobile,
        'recipient_name': wo.patientName,
        'status': '0',
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      if (sendSms) {
        final smsMsg = SmsTemplate.homeCollectionCancellation(rescheduleUrl);

        final smsMessage = Map<String, dynamic>.from(baseMessage);
        smsMessage['_id'] =
            'sms_center:${Util.getDateForId()}:${Util.uuidv4()}';
        smsMessage['message'] = smsMsg;

        debugPrint('📤 Sending cancellation SMS to ${wo.mobile}');
        final result = await comCenter.sendMsg(smsMessage);
        debugPrint(result == 'OK'
            ? '✅ Cancellation SMS sent'
            : '⚠️ SMS failed: $result');
      }

      if (sendWhatsApp) {
        final waMessage = Map<String, dynamic>.from(baseMessage);
        waMessage['_id'] =
            'whatsapp_center:${Util.getDateForId()}:${Util.uuidv4()}';
        waMessage['message'] = [rescheduleUrl];
        waMessage['template'] = 'hc_cancellation';

        debugPrint('📤 Sending cancellation WhatsApp to ${wo.mobile}');
        final result = await comCenter.sendMsg(waMessage);
        debugPrint(result == 'OK'
            ? '✅ Cancellation WhatsApp sent'
            : '⚠️ WhatsApp failed: $result');
      }
    } catch (e) {
      debugPrint('❌ Error sending cancellation messages: $e');
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

import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../../../../screens/time_line_page.dart';
import '../../../widgets/common/common_widgets.dart';
import '../../../../features/theme/theme.dart';

/// Expanded row content for manager work order view.
/// Shows detailed info: address, process steps, prescription, remarks, etc.
class ManagerExpandedContent extends StatelessWidget {
  final WorkOrder workOrder;

  const ManagerExpandedContent({super.key, required this.workOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTable(context),
          SizedBox(height: AppSpacing.md),
          if (workOrder.prescriptionPath.isNotEmpty)
            _buildPrescriptionSection(context),
          if (workOrder.status == 'cancelled') _buildCancellationSection(),
          _buildProcessSteps(),
          SizedBox(height: AppSpacing.md),
          if (workOrder.parsedDoc['remarks'] != null) _buildRemarksSection(),
          if (workOrder.serverStatus == 'Billed') _buildBillInfo(),
          if (workOrder.parsedDoc['report_path'] != null)
            _buildReportSection(context),
          SizedBox(height: AppSpacing.md),
          _buildTimelineButton(context),
        ],
      ),
    );
  }

  Widget _buildInfoTable(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(3),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(2),
      },
      border: TableBorder.all(color: AppColors.tableBorder),
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.surfaceAlt),
          children: const [
            WOTableHeader('Address'),
            WOTableHeader('Pincode'),
            WOTableHeader('Additional Info'),
            WOTableHeader('Ref. By.'),
            WOTableHeader('Email'),
          ],
        ),
        TableRow(
          children: [
            WOTableCell(workOrder.address),
            WOTableCell(workOrder.pincode),
            WOTableCell(workOrder.freeText),
            WOTableCell(_getRefBy()),
            WOTableCell(workOrder.email),
          ],
        ),
      ],
    );
  }

  String _getRefBy() {
    if (workOrder.b2bClientId != null && workOrder.b2bClientId! > 0) {
      return 'B2B: ${workOrder.b2bClientName}';
    }
    if (workOrder.doctorName.isNotEmpty) {
      return 'Dr. ${workOrder.doctorName}';
    }
    return 'Not Specified';
  }

  Widget _buildTimelineButton(BuildContext context) {
    return ActionChip(
      label: const Text('Time Line'),
      backgroundColor: AppColors.secondary.withOpacity(0.15),
      labelStyle: TextStyle(color: AppColors.secondary),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TimeLinePage(workOrder: workOrder),
        ),
      ),
    );
  }

  Widget _buildPrescriptionSection(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Prescription:'),
          backgroundColor: AppColors.error.withOpacity(0.15),
          labelStyle: TextStyle(color: AppColors.error),
        ),
        ActionChip(
          label: Text(_getName(workOrder.prescriptionPath)),
          backgroundColor: AppColors.secondary.withOpacity(0.15),
          labelStyle: TextStyle(color: AppColors.secondary),
          onPressed: () => debugPrint('View: ${workOrder.prescriptionPath}'),
        ),
      ],
    );
  }

  Widget _buildCancellationSection() {
    final reason = workOrder.parsedDoc['cancel_reason'] ?? 'N/A';
    return Chip(
      label: Text('Cancellation Reason: $reason'),
      backgroundColor: AppColors.error.withOpacity(0.15),
      labelStyle: TextStyle(color: AppColors.error),
    );
  }

  Widget _buildProcessSteps() {
    final process = workOrder.process;
    bool isStepDone(String? key) =>
        process[key] != null && process[key].toString().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HC Process Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-1',
          workOrder.firstStep.isNotEmpty
              ? 'Delay: ${workOrder.firstStep}'
              : 'Pending / No Delay',
          isDone: workOrder.firstStep.isNotEmpty,
        ),
        SizedBox(height: AppSpacing.sm),
        _buildProformaStep(workOrder.proformaPath),
        SizedBox(height: AppSpacing.sm),
        _buildGenericStep(
          'Step-3',
          isStepDone('third_step')
              ? 'Bill: ${process['third_step']}'
              : 'Pending',
          isDone: isStepDone('third_step'),
        ),
        SizedBox(height: AppSpacing.sm),
        _buildGenericStep(
          'Step-4',
          isStepDone('fourth_step')
              ? 'OTP: ${process['fourth_step']}'
              : 'Pending',
          isDone: isStepDone('fourth_step'),
        ),
        SizedBox(height: AppSpacing.sm),
        _buildPrescriptionPhotoStep(process['fifth_step']),
      ],
    );
  }

  Widget _buildGenericStep(String label, String content,
      {bool isDone = false}) {
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(label),
          backgroundColor: isDone
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.textHint.withOpacity(0.1),
          labelStyle:
              TextStyle(color: isDone ? AppColors.primary : AppColors.textHint),
          padding: EdgeInsets.zero,
        ),
        Text(
          content,
          style: TextStyle(
              color: isDone ? AppColors.textPrimary : AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildProformaStep(String? stepData) {
    final isDone = stepData != null && stepData.isNotEmpty;
    String statusText = 'Pending';
    if (isDone) {
      if (workOrder.b2bClientId != null && workOrder.b2bClientId! > 0) {
        statusText = 'Not Sent (B2B)';
      } else if (workOrder.credit == 1) {
        statusText = 'Not Sent (Credit)';
      } else if (workOrder.credit == 2) {
        statusText = 'Not Sent (Trial)';
      } else {
        statusText = 'Sent';
      }
    }
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Step-2'),
          backgroundColor: isDone
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.textHint.withOpacity(0.1),
          labelStyle:
              TextStyle(color: isDone ? AppColors.primary : AppColors.textHint),
          padding: EdgeInsets.zero,
        ),
        Text(
          'Proforma Invoice:',
          style: TextStyle(
              color: isDone ? AppColors.textPrimary : AppColors.textHint),
        ),
        if (isDone)
          Chip(
            label: Text(statusText),
            backgroundColor:
                (statusText == 'Sent' ? AppColors.success : AppColors.error)
                    .withOpacity(0.15),
            labelStyle: TextStyle(
              color: statusText == 'Sent' ? AppColors.success : AppColors.error,
            ),
          ),
      ],
    );
  }

  Widget _buildPrescriptionPhotoStep(dynamic stepData) {
    final isDone = stepData != null && stepData.toString().isNotEmpty;
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Step-5'),
          backgroundColor: isDone
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.textHint.withOpacity(0.1),
          labelStyle:
              TextStyle(color: isDone ? AppColors.primary : AppColors.textHint),
          padding: EdgeInsets.zero,
        ),
        Text(
          'Prescription Photo:',
          style: TextStyle(
              color: isDone ? AppColors.textPrimary : AppColors.textHint),
        ),
        if (isDone)
          ActionChip(
            label: Text(_getPrescriptionFileNames('$stepData')),
            backgroundColor: AppColors.secondary.withOpacity(0.15),
            labelStyle: TextStyle(color: AppColors.secondary),
            onPressed: () {},
          ),
        if (!isDone)
          Text('Pending', style: TextStyle(color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildRemarksSection() {
    final remarks = workOrder.parsedDoc['remarks']?.toString() ?? '';
    final hasRemarks = remarks.trim().isNotEmpty;
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: const Text('Remarks'),
          backgroundColor: hasRemarks
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.textHint.withOpacity(0.1),
          labelStyle: TextStyle(
              color: hasRemarks ? AppColors.primary : AppColors.textHint),
          padding: EdgeInsets.zero,
        ),
        Text(
          hasRemarks ? remarks : 'No Remarks',
          style: TextStyle(
              color: hasRemarks ? AppColors.textPrimary : AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildBillInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GenericSection(
          label: 'Bill No',
          value: workOrder.billNumber,
          color: AppColors.secondary,
        ),
        SizedBox(height: AppSpacing.xs),
        _GenericSection(
          label: 'Lab No',
          value: workOrder.labNumber,
          color: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildReportSection(BuildContext context) {
    final status = '${workOrder.parsedDoc['report_status']}';
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        Chip(
          label: const Text('Lab Result:'),
          backgroundColor: AppColors.primary.withOpacity(0.15),
          labelStyle: TextStyle(color: AppColors.primary),
        ),
        Chip(
          label: Text(status),
          backgroundColor: AppColors.primary.withOpacity(0.15),
          labelStyle: TextStyle(color: AppColors.primary),
        ),
        ActionChip(
          label: const Text('Report PDF'),
          backgroundColor: AppColors.secondary.withOpacity(0.15),
          labelStyle: TextStyle(color: AppColors.secondary),
          onPressed: () {},
        ),
      ],
    );
  }

  String _getName(dynamic name) {
    if (name == null) return '';
    String n = name.toString();
    return n.contains('/') ? n.substring(n.lastIndexOf('/') + 1) : n;
  }

  String _getPrescriptionFileNames(String name) {
    if (name.isEmpty) return '';
    List<String> a = name.contains(',') ? name.split(',') : [name];
    return a.length > 1 ? '${a.length} files' : _getName(name);
  }
}

/// Generic section widget for displaying label-value pairs.
class _GenericSection extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isLink;

  const _GenericSection({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text('$label:'),
          backgroundColor: color.withOpacity(0.15),
          labelStyle: TextStyle(color: color),
        ),
        isLink
            ? ActionChip(
                label: Text(value),
                backgroundColor: AppColors.secondary.withOpacity(0.15),
                labelStyle: TextStyle(color: AppColors.secondary),
                onPressed: () {},
              )
            : Text(value),
      ],
    );
  }
}

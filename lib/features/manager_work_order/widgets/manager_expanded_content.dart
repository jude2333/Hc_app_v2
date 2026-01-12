import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/components/time_line_page.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import '../../theme/theme.dart';

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
          const SizedBox(height: AppSpacing.md),
          if (workOrder.prescriptionPath.isNotEmpty)
            _buildPrescriptionSection(context),
          if (workOrder.status == 'cancelled') _buildCancellationSection(),
          _buildProcessSteps(),
          const SizedBox(height: AppSpacing.md),
          if (workOrder.parsedDoc['remarks'] != null) _buildRemarksSection(),
          if (workOrder.serverStatus == 'Billed') _buildBillInfo(),
          if (workOrder.parsedDoc['report_path'] != null)
            _buildReportSection(context),
          const SizedBox(height: AppSpacing.md),
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
    return _ActionLinkChip(
      label: 'Time Line',
      color: AppColors.secondary,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TimeLinePage(workOrder: workOrder),
        ),
      ),
    );
  }

  Widget _buildPrescriptionSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LabelChip(label: 'Prescription', color: AppColors.error),
          _ActionLinkChip(
            label: _getName(workOrder.prescriptionPath),
            color: AppColors.secondary,
            onTap: () => debugPrint('View: ${workOrder.prescriptionPath}'),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationSection() {
    final reason = workOrder.parsedDoc['cancel_reason'] ?? 'N/A';
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: _FilledChip(
        label: 'Cancelled: $reason',
        color: AppColors.error,
      ),
    );
  }

  Widget _buildProcessSteps() {
    final process = workOrder.process;
    bool isStepDone(String? key) =>
        process[key] != null && process[key].toString().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HC Process Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-1',
          workOrder.firstStep.isNotEmpty
              ? 'Delay: ${workOrder.firstStep}'
              : 'Pending / No Delay',
          isDone: workOrder.firstStep.isNotEmpty,
        ),
        SizedBox(height: AppSpacing.xs),
        _buildProformaStep(workOrder.proformaPath),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-3',
          isStepDone('third_step')
              ? 'Bill: ${process['third_step']}'
              : 'Pending',
          isDone: isStepDone('third_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-4',
          isStepDone('fourth_step')
              ? 'OTP: ${process['fourth_step']}'
              : 'Pending',
          isDone: isStepDone('fourth_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildPrescriptionPhotoStep(process['fifth_step']),
      ],
    );
  }

  Widget _buildGenericStep(String label, String content,
      {bool isDone = false}) {
    return Row(
      children: [
        _BorderedChip(
          label: label,
          color: isDone ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: isDone
              ? _FilledChip(label: content, color: AppColors.success)
              : Text(
                  content,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  overflow: TextOverflow.ellipsis,
                ),
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
    return Row(
      children: [
        _BorderedChip(
          label: 'Step-2',
          color: isDone ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Proforma:',
          style: TextStyle(
            fontSize: 11,
            color: isDone ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isDone)
          _FilledChip(
            label: statusText,
            color: statusText == 'Sent' ? AppColors.success : AppColors.error,
          ),
        if (!isDone)
          Text('Pending',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildPrescriptionPhotoStep(dynamic stepData) {
    final isDone = stepData != null && stepData.toString().isNotEmpty;
    return Row(
      children: [
        _BorderedChip(
          label: 'Step-5',
          color: isDone ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Photos:',
          style: TextStyle(
            fontSize: 11,
            color: isDone ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isDone)
          _ActionLinkChip(
            label: _getPrescriptionFileNames('$stepData'),
            color: AppColors.secondary,
            onTap: () {},
          ),
        if (!isDone)
          Text('Pending',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildRemarksSection() {
    final remarks = workOrder.parsedDoc['remarks']?.toString() ?? '';
    final hasRemarks = remarks.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelChip(label: 'Remarks', color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hasRemarks ? remarks : 'No Remarks',
              style: TextStyle(
                fontSize: 12,
                color: hasRemarks ? AppColors.textPrimary : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillInfo() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          _FilledChip(
            label: 'Bill: ${workOrder.billNumber}',
            color: AppColors.secondary,
          ),
          _FilledChip(
            label: 'Lab: ${workOrder.labNumber}',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(BuildContext context) {
    final status = '${workOrder.parsedDoc['report_status']}';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _LabelChip(label: 'Lab Result', color: AppColors.primary),
        _FilledChip(label: status, color: AppColors.success),
        _ActionLinkChip(
          label: 'Report PDF',
          color: AppColors.secondary,
          onTap: () {},
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

// ============================================================================
// COMPACT CHIP WIDGETS (matching status chip style)
// ============================================================================

/// Bordered chip (outline only) - like Status chip
class _BorderedChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BorderedChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Filled chip (background color) - like Server Status chip
class _FilledChip extends StatelessWidget {
  final String label;
  final Color color;

  const _FilledChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Label chip (for section headers)
class _LabelChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LabelChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Clickable action chip
class _ActionLinkChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionLinkChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

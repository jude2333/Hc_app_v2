import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

/// Expanded content for search result details
class SearchExpandedContent extends StatelessWidget {
  final Map<String, dynamic> item;

  const SearchExpandedContent({super.key, required this.item});

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
          if (item['pres_photo'] != null) _buildPrescriptionSection(),
          if (item['status'] == 'cancelled') _buildCancellationSection(),
          _buildProcessSteps(),
          SizedBox(height: AppSpacing.md),
          if (item['remarks'] != null) _buildRemarksSection(),
          if (item['server_status'] == 'Billed') _buildBillInfo(),
          if (item['report_path'] != null) _buildReportSection(),
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
            _TableHeader('Address'),
            _TableHeader('Pincode'),
            _TableHeader('Additional Info'),
            _TableHeader('Ref. By'),
            _TableHeader('Email'),
          ],
        ),
        TableRow(
          children: [
            _TableCell('${item['address'] ?? ''}'),
            _TableCell('${item['pincode'] ?? ''}'),
            _TableCell('${item['free_text'] ?? ''}'),
            _TableCell(_getRefBy()),
            _TableCell('${item['email'] ?? ''}'),
          ],
        ),
      ],
    );
  }

  String _getRefBy() {
    if (item['b2b_client_id'] != null) {
      return 'B2B: ${item['b2b_client_name'] ?? ''}';
    }
    return 'Dr. ${item['doctor_name'] ?? ''}';
  }

  Widget _buildPrescriptionSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LabelChip(label: 'Prescription', color: AppColors.error),
          _ActionLinkChip(
            label: _getName(item['pres_photo']),
            color: AppColors.secondary,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: _FilledChip(
        label: 'Cancelled: ${item['cancel_reason'] ?? 'N/A'}',
        color: AppColors.error,
      ),
    );
  }

  Widget _buildProcessSteps() {
    final process = item['process'] as Map<String, dynamic>? ?? {};
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
        SizedBox(height: AppSpacing.xs),
        _buildStep('Step-1', process['first_step'], 'Delay'),
        _buildStep('Step-2', process['second_step'], 'Proforma'),
        _buildStep('Step-3', process['third_step'], 'Bill'),
        _buildStep('Step-4', process['fourth_step'], 'OTP'),
        _buildStep('Step-5', process['fifth_step'], 'Photos'),
      ],
    );
  }

  Widget _buildStep(String label, dynamic value, String context) {
    final isDone = value != null && value.toString().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          _BorderedChip(
            label: label,
            color: isDone ? AppColors.primary : AppColors.textHint,
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: isDone
                ? _FilledChip(
                    label: '$context: $value',
                    color: AppColors.success,
                  )
                : Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksSection() {
    final remarks = item['remarks']?.toString() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelChip(label: 'Remarks', color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              remarks,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
            label: 'Bill: ${item['bill_number'] ?? ''}',
            color: AppColors.secondary,
          ),
          _FilledChip(
            label: 'Lab: ${item['lab_number'] ?? ''}',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _LabelChip(label: 'Lab Result', color: AppColors.primary),
        _FilledChip(
          label: '${item['report_status'] ?? ''}',
          color: AppColors.success,
        ),
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
        softWrap: true,
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

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

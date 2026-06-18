import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/components/time_line_page.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/copyable_text.dart';
import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
import 'package:anderson_crm_flutter/services/s3_file_cache.dart';
import '../../theme/theme.dart';

class ManagerExpandedContent extends ConsumerWidget {
  final WorkOrder workOrder;

  const ManagerExpandedContent({super.key, required this.workOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTable(context),
          const SizedBox(height: AppSpacing.md),
          if (workOrder.prescriptionPhoto.isNotEmpty)
            _buildPrescriptionSection(context, ref),
          if (workOrder.status == 'cancelled') _buildCancellationSection(),
          if (workOrder.marketingPersonName.isNotEmpty ||
              workOrder.marketingPersonNumber.isNotEmpty)
            _buildMarketingSection(),
          if (workOrder.alternateMobile.isNotEmpty ||
              workOrder.clientCode.isNotEmpty ||
              workOrder.doctorCode.isNotEmpty)
            _buildCodesSection(),
          _buildProcessSteps(context, ref),
          const SizedBox(height: AppSpacing.md),
          if (workOrder.parsedDoc['remarks'] != null) _buildRemarksSection(context),
          if (workOrder.serverStatus == 'Billed') _buildBillInfo(),
          if (workOrder.parsedDoc['report_path'] != null)
            _buildReportSection(context, ref),
          const SizedBox(height: AppSpacing.md),
          _buildTimelineButton(context),
        ],
      ),
    );
  }

  Widget _buildInfoTable(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(3),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(2),
      },
      border: TableBorder.all(
        color: isDark ? AppColors.darkBorder : AppColors.tableBorder,
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
          ),
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
        if (workOrder.alternateMobile.isNotEmpty) ...[
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
            ),
            children: const [
              WOTableHeader('Alt. Mobile'),
              WOTableHeader('Client Code'),
              WOTableHeader('Doctor Code'),
              WOTableHeader(''),
              WOTableHeader(''),
            ],
          ),
          TableRow(
            children: [
              WOTableCell(workOrder.alternateMobile, isPhoneNumber: true),
              WOTableCell(workOrder.clientCode),
              WOTableCell(workOrder.doctorCode),
              WOTableCell(''),
              WOTableCell(''),
            ],
          ),
        ],
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

  Widget _buildPrescriptionSection(BuildContext context, WidgetRef ref) {
    final path = workOrder.prescriptionPhoto;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LabelChip(label: 'Prescription', color: AppColors.error),
          _ActionLinkChip(
            label: _getPrescriptionFileNames(path),
            color: AppColors.secondary,
            onTap: () => _viewFile(context, ref, path),
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

  Widget _buildMarketingSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LabelChip(label: 'Marketing Person', color: AppColors.primary),
          if (workOrder.marketingPersonName.isNotEmpty)
            _FilledChip(
                label: workOrder.marketingPersonName,
                color: AppColors.secondary),
          if (workOrder.marketingPersonNumber.isNotEmpty)
            _FilledChip(
                label: workOrder.marketingPersonNumber,
                color: AppColors.secondary,
                isPhoneNumber: true),
        ],
      ),
    );
  }

  Widget _buildCodesSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (workOrder.alternateMobile.isNotEmpty) ...[
            _LabelChip(label: 'Alt. Mobile', color: AppColors.primary),
            _FilledChip(
                label: workOrder.alternateMobile,
                color: AppColors.secondary,
                isPhoneNumber: true),
          ],
          if (workOrder.clientCode.isNotEmpty) ...[
            _LabelChip(label: 'Client Code', color: AppColors.primary),
            _FilledChip(
                label: workOrder.clientCode, color: AppColors.secondary),
          ],
          if (workOrder.doctorCode.isNotEmpty) ...[
            _LabelChip(label: 'Doctor Code', color: AppColors.primary),
            _FilledChip(
                label: workOrder.doctorCode, color: AppColors.secondary),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessSteps(BuildContext context, WidgetRef ref) {
    final process = workOrder.process;
    bool isStepDone(String? key) =>
        process[key] != null && process[key].toString().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HC Process Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          context,
          'Step-1',
          workOrder.firstStep.isNotEmpty
              ? 'Delay: ${workOrder.firstStep}'
              : 'Pending / No Delay',
          isDone: workOrder.firstStep.isNotEmpty,
        ),
        SizedBox(height: AppSpacing.xs),
        _buildProformaStep(context, ref, workOrder.proformaPath),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          context,
          'Step-3',
          isStepDone('third_step')
              ? 'Bill: ${process['third_step']}'
              : 'Pending',
          isDone: isStepDone('third_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          context,
          'Step-4',
          isStepDone('fourth_step')
              ? 'OTP: ${process['fourth_step']}'
              : 'Pending',
          isDone: isStepDone('fourth_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildPrescriptionPhotoStep(context, ref, process['fifth_step']),
      ],
    );
  }

  Widget _buildGenericStep(BuildContext context, String label, String content,
      {bool isDone = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _BorderedChip(
          label: label,
          color: isDone ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.textHint),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: isDone
              ? _FilledChip(label: content, color: AppColors.success)
              : Text(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }

  Widget _buildProformaStep(BuildContext context, WidgetRef ref, String? stepData) {
    final isDone = stepData != null && stepData.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          color: isDone ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.textHint),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Proforma:',
          style: TextStyle(
            fontSize: 11,
            color: isDone
                ? Theme.of(context).colorScheme.onSurface
                : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isDone) ...[
          _FilledChip(
            label: statusText,
            color: statusText == 'Sent' ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: AppSpacing.xs),
          Builder(
            builder: (context) => _ActionLinkChip(
              label: 'View PDF',
              color: AppColors.secondary,
              onTap: () => _viewFile(context, ref, stepData),
            ),
          ),
        ],
        if (!isDone)
          Text('Pending',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
              )),
      ],
    );
  }

  Widget _buildPrescriptionPhotoStep(BuildContext context, WidgetRef ref, dynamic stepData) {
    final isDone = stepData != null && stepData.toString().isNotEmpty;
    final path = stepData?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _BorderedChip(
          label: 'Step-5',
          color: isDone ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.textHint),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Photos:',
          style: TextStyle(
            fontSize: 11,
            color: isDone
                ? Theme.of(context).colorScheme.onSurface
                : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isDone)
          Builder(
            builder: (context) => _ActionLinkChip(
              label: _getPrescriptionFileNames(path),
              color: AppColors.secondary,
              onTap: () => _viewFile(context, ref, path),
            ),
          ),
        if (!isDone)
          Text('Pending',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
              )),
      ],
    );
  }

  Widget _buildRemarksSection(BuildContext context) {
    final remarks = workOrder.parsedDoc['remarks']?.toString() ?? '';
    final hasRemarks = remarks.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: hasRemarks
                    ? Theme.of(context).colorScheme.onSurface
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
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

  Widget _buildReportSection(BuildContext context, WidgetRef ref) {
    final status = '${workOrder.parsedDoc['report_status']}';
    final reportPath = workOrder.parsedDoc['report_path']?.toString() ?? '';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _LabelChip(label: 'Lab Result', color: AppColors.primary),
        _FilledChip(label: status, color: AppColors.success),
        _ActionLinkChip(
          label: 'Report PDF',
          color: AppColors.secondary,
          onTap: () => _viewFile(context, ref, reportPath),
        ),
      ],
    );
  }

  void _viewFile(BuildContext context, WidgetRef ref, String path) {
    if (path.isEmpty) return;

    final files = path.contains(',')
        ? path.split(',').map((f) => f.trim()).toList()
        : [path];

    if (files.length == 1) {
      _openFileViewer(context, files.first);
    } else {
      FilePickerDialog.show(
        context,
        files: files,
        title: 'View / Download Files',
        onAction: (selectedPath, action) {
          if (action == 'view') {
            _openFileViewer(context, selectedPath);
          } else {
            _downloadFile(context, ref, selectedPath);
          }
        },
      );
    }
  }

  void _openFileViewer(BuildContext context, String path) async {
    try {
      final fileName = FileService.getFileName(path);

      if (FileService.isPdf(path)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerPage(
              s3Path: path,
              title: fileName,
            ),
          ),
        );
      } else if (FileService.isImage(path)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(
              s3Path: path,
              title: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadFile(
      BuildContext context, WidgetRef ref, String path) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = FileService.getFileName(path);

    messenger.showSnackBar(
      SnackBar(content: Text('Downloading: $fileName')),
    );

    try {
      final cache = ref.read(s3FileCacheProvider);
      final Uint8List bytes = await cache.getFile(path);
      final ext = FileService.getExtension(path).replaceAll('.', '');
      final mimeType =
          FileService.isPdf(path) ? 'application/pdf' : 'image/$ext';

      await FileService.saveOrOpenFile(
        context,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('[ManagerExpanded] Download error: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

class _FilledChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isPhoneNumber;

  const _FilledChip(
      {required this.label, required this.color, this.isPhoneNumber = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CopyableText(
        label,
        isPhoneNumber: isPhoneNumber,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

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

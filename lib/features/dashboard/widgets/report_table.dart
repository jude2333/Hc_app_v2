import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import '../models/dashboard_report.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class ReportDataTable extends StatelessWidget {
  final List<ReportRow> rows;
  final ReportType type;
  final double minWidth;

  const ReportDataTable({
    super.key,
    required this.rows,
    required this.type,
    this.minWidth = 1000,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop/tablet: existing table with horizontal scroll
        if (constraints.maxWidth >= 600) {
          return _buildDesktopTable(context, constraints);
        }
        // Mobile: compact card layout
        return _buildMobileCards(context);
      },
    );
  }

  Widget _buildDesktopTable(BuildContext context, BoxConstraints constraints) {
    final double tableWidth =
        constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              ...rows.map((row) => _buildDataRow(context, row)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: rows.map((row) {
        final m = row.metrics;
        final isTotal = row.isTotal;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isTotal
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surface,
            borderRadius: AppRadius.xlAll,
            border: Border.all(
              color: isTotal
                  ? AppColors.andersonBlue.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period label
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color:
                      isTotal ? AppColors.andersonBlue : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Status chips row
              Row(
                children: [
                  _buildChip(
                      'A', m.assigned.toString(), Colors.blue, colorScheme),
                  const SizedBox(width: 6),
                  _buildChip('F', m.finished.toString(), AppColors.success,
                      colorScheme),
                  const SizedBox(width: 6),
                  _buildChip('P', m.pending.toString(), AppColors.primary,
                      colorScheme),
                  const SizedBox(width: 6),
                  _buildChip('C', m.cancelled.toString(), AppColors.error,
                      colorScheme),
                ],
              ),
              const SizedBox(height: 8),
              // Financial row
              Row(
                children: [
                  Expanded(
                    child: _buildFinancialItem(
                        'Collection', m.collection, Colors.indigo, colorScheme,
                        isBold: isTotal),
                  ),
                  Expanded(
                    child: _buildFinancialItem(
                        'Received', m.received, AppColors.success, colorScheme,
                        isBold: isTotal),
                  ),
                  Expanded(
                    child: _buildFinancialItem(
                        'Credit', m.credit, Colors.purple, colorScheme,
                        isBold: isTotal),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChip(
      String label, String value, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(
      String label, double value, Color color, ColorScheme colorScheme,
      {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Util.formatMoney(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.andersonBlue,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          _HeaderCell(type.periodLabel, flex: 2),
          const _HeaderCell('Assigned', flex: 1),
          const _HeaderCell('Finished', flex: 1),
          const _HeaderCell('Cancelled', flex: 1),
          const _HeaderCell('Pending', flex: 1),
          const _HeaderCell('Total\nCollection', flex: 2),
          const _HeaderCell('Received', flex: 2),
          const _HeaderCell('Credit', flex: 2),
          const _HeaderCell('B2B', flex: 1),
          const _HeaderCell('Trial', flex: 1),
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, ReportRow row) {
    final m = row.metrics;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: row.isTotal
            ? (isDark ? AppColors.darkSurfaceAlt : Colors.grey.shade100)
            : Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          _DataCell(row.label, flex: 2, isBold: row.isTotal),
          _DataCell(m.assigned.toString(), flex: 1, isBold: row.isTotal),
          _DataCell(m.finished.toString(), flex: 1, isBold: row.isTotal),
          _DataCell(m.cancelled.toString(), flex: 1, isBold: row.isTotal),
          _DataCell(m.pending.toString(), flex: 1, isBold: row.isTotal),
          _DataCell(Util.formatMoney(m.collection),
              flex: 2, isBold: row.isTotal),
          _DataCell(Util.formatMoney(m.received), flex: 2, isBold: row.isTotal),
          _DataCell(Util.formatMoney(m.credit), flex: 2, isBold: row.isTotal),
          _DataCell(Util.formatMoney(m.b2b), flex: 1, isBold: row.isTotal),
          _DataCell(Util.formatMoney(m.trial), flex: 1, isBold: row.isTotal),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isBold;

  const _DataCell(this.text, {required this.flex, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}

class MetricsGrid extends StatelessWidget {
  final DashboardMetrics metrics;

  const MetricsGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _MetricCard(
              title: 'ASSIGNED',
              value: metrics.assigned.toString(),
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              title: 'FINISHED',
              value: metrics.finished.toString(),
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _MetricCard(
              title: 'CANCELLED',
              value: metrics.cancelled.toString(),
              color: Colors.red,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              title: 'PENDING',
              value: metrics.pending.toString(),
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FinancialCard(
          title: 'TOTAL COLLECTION',
          value: metrics.collection,
          color: Colors.indigo,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;

  const _FinancialCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL COLLECTION',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Util.formatMoney(value),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wallet, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import '../models/dashboard_report.dart';

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
        final double tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  ...rows.map((row) => _buildDataRow(row)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.blue,
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

  Widget _buildDataRow(ReportRow row) {
    final m = row.metrics;

    return Container(
      decoration: BoxDecoration(
        color: row.isTotal ? Colors.grey.shade50 : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
          color: Colors.black87,
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
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
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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

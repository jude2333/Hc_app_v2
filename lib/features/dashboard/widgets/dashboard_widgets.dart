import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

class DashboardDateHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;

  const DashboardDateHeader({
    super.key,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(selectedDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateFormat('dd MMMM yyyy').format(selectedDate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          _buildCalendarButton(onTap),
        ],
      ),
    );
  }
}

class DashboardDateRangeHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const DashboardDateRangeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 12),
              ],
              _buildCalendarButton(onTap),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _buildCalendarButton(VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: const Icon(Icons.calendar_month_rounded, color: Colors.orange),
    ),
  );
}

class DashboardSkeletonLoading extends StatelessWidget {
  const DashboardSkeletonLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBox(width: 120, height: 20),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCardSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCardSkeleton()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCardSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCardSkeleton()),
            ],
          ),
          const SizedBox(height: 24),
          _buildTableSkeleton(),
          const SizedBox(height: 24),
          _buildChartSkeleton(),
        ],
      ),
    );
  }

  Widget _buildMetricCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Removed border and shadow for performance
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBox(width: 60, height: 10),
          const SizedBox(height: 8),
          _buildShimmerBox(width: 80, height: 24),
        ],
      ),
    );
  }

  Widget _buildTableSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: List.generate(
                  6,
                  (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )),
            ),
          ),
          ...List.generate(
              5,
              (index) => Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100)),
                    ),
                    child: Row(
                      children: List.generate(
                          6,
                          (i) => Expanded(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              )),
                    ),
                  )),
        ],
      ),
    );
  }

  Widget _buildChartSkeleton() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Removed shadow
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              5,
              (index) => Container(
                    width: 24,
                    height: 80 + (index * 15).toDouble(),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  )),
        ),
      ),
    );
  }
}

Widget _buildShimmerBox({required double width, required double height}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class DashboardHeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const DashboardHeaderCell(this.text, {super.key, required this.flex});

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

class DashboardDataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isBold;

  const DashboardDataCell(
    this.text, {
    super.key,
    required this.flex,
    this.isBold = false,
  });

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

class DashboardDetailedTable extends StatelessWidget {
  final List<String> headers;
  final List<int> flexValues;
  final List<Map<String, dynamic>> data;
  final List<String> dataKeys;
  final String? labelKey;
  final double minWidth;

  const DashboardDetailedTable({
    super.key,
    required this.headers,
    required this.flexValues,
    required this.data,
    required this.dataKeys,
    this.labelKey,
    this.minWidth = 1000,
  });

  @override
  Widget build(BuildContext context) {
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
                  Container(
                    color: Colors.blue,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: List.generate(
                          headers.length,
                          (index) => DashboardHeaderCell(
                                headers[index],
                                flex: flexValues[index],
                              )),
                    ),
                  ),
                  ...data.map((row) {
                    final isTotal = row['isTotal'] == true ||
                        row['label'] == 'Total' ||
                        row['month'] == 'Total';
                    return Container(
                      decoration: BoxDecoration(
                        color: isTotal ? Colors.grey.shade50 : Colors.white,
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Row(
                        children: List.generate(dataKeys.length, (index) {
                          final key = dataKeys[index];
                          final value = row[key];
                          String displayValue;

                          if (value == null) {
                            displayValue = '';
                          } else if (value is double) {
                            displayValue = Util.formatMoney(value);
                          } else if (value is int && _isMoneyField(key)) {
                            displayValue = Util.formatMoney(value.toDouble());
                          } else {
                            displayValue = value.toString();
                          }

                          return DashboardDataCell(
                            displayValue,
                            flex: flexValues[index],
                            isBold: isTotal,
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isMoneyField(String key) {
    return ['collection', 'received', 'credit', 'b2b', 'trial'].contains(key);
  }
}

double calculateMaxY(List<int> values, {double multiplier = 1.2}) {
  if (values.isEmpty) return 10;
  final max = values.reduce((a, b) => a > b ? a : b);
  return (max * multiplier).ceilToDouble();
}

double calculateInterval(double maxY, {int divisions = 5}) {
  if (maxY <= 10) return 2;
  return (maxY / divisions).ceilToDouble();
}

String formatCompactNumber(int value) {
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

BarTouchData buildBarTouchData({bool isMoney = false}) {
  return BarTouchData(
    enabled: true,
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => Colors.blueGrey.shade800,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tooltipRoundedRadius: 8,
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        final val = rod.toY.toInt();
        return BarTooltipItem(
          isMoney ? Util.formatMoney(val.toDouble()) : val.toString(),
          const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        );
      },
    ),
  );
}

BarChartRodData buildGradientBar({
  required double value,
  required Color color,
  double width = 12,
  double? maxY,
}) {
  return BarChartRodData(
    toY: value,
    gradient: LinearGradient(
      colors: [color, color.withOpacity(0.6)],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ),
    width: width,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(4),
    ),
    backDrawRodData: maxY != null
        ? BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: color.withOpacity(0.05),
          )
        : null,
  );
}

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final Color color;
  final bool isMoney;

  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.isMoney = false,
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
              isMoney
                  ? Util.formatMoney((value as num).toDouble())
                  : value.toString(),
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

class DashboardFinancialCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final Color color;

  const DashboardFinancialCard({
    super.key,
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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Util.formatMoney((value as num).toDouble()),
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

class DashboardSectionTitle extends StatelessWidget {
  final String title;

  const DashboardSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class DashboardEmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const DashboardEmptyState({
    super.key,
    this.message = 'No data available',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child:
                  const Text('Retry', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ],
      ),
    );
  }
}

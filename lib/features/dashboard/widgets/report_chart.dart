import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/dashboard_report.dart';
import 'package:anderson_crm_flutter/util.dart';

class AnimatedChartWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const AnimatedChartWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedChartWrapper> createState() => _AnimatedChartWrapperState();
}

class _AnimatedChartWrapperState extends State<AnimatedChartWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  final List<LegendItem> items;

  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: items.map((item) => _LegendItemWidget(item: item)).toList(),
      ),
    );
  }
}

class LegendItem {
  final String label;
  final Color color;

  const LegendItem({required this.label, required this.color});
}

class _LegendItemWidget extends StatelessWidget {
  final LegendItem item;

  const _LegendItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class DailyCasesChart extends StatelessWidget {
  final ChartData data;

  const DailyCasesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final allValues = [
      ...data.assigned,
      ...data.finished,
      ...data.cancelled,
      ...data.pending,
    ];
    final maxValue =
        allValues.isEmpty ? 10 : allValues.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.2).ceilToDouble();
    final interval = maxY <= 10 ? 2.0 : (maxY / 5).ceilToDouble();

    return AnimatedChartWrapper(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8)],
        ),
        child: Column(
          children: [
            const ChartLegend(items: [
              LegendItem(label: 'Assigned', color: Colors.blue),
              LegendItem(label: 'Finished', color: Colors.green),
              LegendItem(label: 'Cancelled', color: Colors.red),
              LegendItem(label: 'Pending', color: Colors.orange),
            ]),
            AspectRatio(
              aspectRatio: 5.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey.shade800,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tooltipRoundedRadius: 6,
                      getTooltipItem: (group, _, rod, __) {
                        final labels = [
                          'Assigned',
                          'Finished',
                          'Cancel',
                          'Pending'
                        ];
                        return BarTooltipItem(
                          '${labels[group.x]}: ${rod.toY.toInt()}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: interval,
                        getTitlesWidget: (v, _) => v == 0
                            ? const SizedBox.shrink()
                            : Text(v.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.black54)),
                      ),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final labels = ['A', 'F', 'C', 'P'];
                          if (v.toInt() >= labels.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labels[v.toInt()],
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarGroup(0, data.assigned[0], Colors.blue),
                    _buildBarGroup(1, data.finished[0], Colors.green),
                    _buildBarGroup(2, data.cancelled[0], Colors.red),
                    _buildBarGroup(3, data.pending[0], Colors.orange),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, int value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

class DailyFinancialChart extends StatelessWidget {
  final FinancialChartData data;

  const DailyFinancialChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final allValues = [
      ...data.collection,
      ...data.received,
      ...data.credit,
      ...data.b2b,
      ...data.trial,
    ];
    final maxValue =
        allValues.isEmpty ? 1000 : allValues.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.2).ceilToDouble();
    final interval = maxY <= 10000 ? 2000.0 : (maxY / 5).ceilToDouble();

    return AnimatedChartWrapper(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8)],
        ),
        child: Column(
          children: [
            const ChartLegend(items: [
              LegendItem(label: 'Collection', color: Colors.indigo),
              LegendItem(label: 'Received', color: Colors.teal),
              LegendItem(label: 'Credit', color: Colors.purple),
              LegendItem(label: 'B2B', color: Colors.brown),
              LegendItem(label: 'Trial', color: Colors.grey),
            ]),
            AspectRatio(
              aspectRatio: 4.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey.shade800,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tooltipRoundedRadius: 6,
                      getTooltipItem: (group, _, rod, __) {
                        final labels = [
                          'Collection',
                          'Received',
                          'Credit',
                          'B2B',
                          'Trial'
                        ];
                        return BarTooltipItem(
                          '${labels[group.x]}: ${Util.formatMoney(rod.toY)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: interval,
                        getTitlesWidget: (v, _) {
                          if (v == 0) return const SizedBox.shrink();
                          if (v >= 100000)
                            return Text('${(v / 100000).toStringAsFixed(1)}L',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.black54));
                          if (v >= 1000)
                            return Text('${(v / 1000).toStringAsFixed(0)}K',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.black54));
                          return Text(v.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.black54));
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final labels = ['Col', 'Rec', 'Cre', 'B2B', 'Tri'];
                          if (v.toInt() >= labels.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labels[v.toInt()],
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarGroup(0, data.collection[0], Colors.indigo),
                    _buildBarGroup(1, data.received[0], Colors.teal),
                    _buildBarGroup(2, data.credit[0], Colors.purple),
                    _buildBarGroup(3, data.b2b[0], Colors.brown),
                    _buildBarGroup(4, data.trial[0], Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, int value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

class ReportCasesChart extends StatelessWidget {
  final ChartData data;
  final String title;

  const ReportCasesChart({
    super.key,
    required this.data,
    this.title = 'Cases Overview',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = _calculateMaxY();
    final interval = _calculateInterval(maxY);

    return AnimatedChartWrapper(
      delay: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const ChartLegend(items: [
              LegendItem(label: 'Finished', color: Colors.green),
              LegendItem(label: 'Assigned', color: Colors.blue),
            ]),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: _buildBarTouchData(),
                  titlesData: _buildTitlesData(interval),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.grey.shade100,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(data.labels.length, (index) {
      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: data.finished[index].toDouble(),
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: data.labels.length > 7 ? 8 : 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: data.assigned[index].toDouble(),
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: data.labels.length > 7 ? 8 : 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => Colors.blueGrey.shade800,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tooltipRoundedRadius: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final label = rodIndex == 0 ? 'Finished' : 'Assigned';
          return BarTooltipItem(
            '$label: ${rod.toY.toInt()}',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          );
        },
      ),
    );
  }

  FlTitlesData _buildTitlesData(double interval) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: interval,
          getTitlesWidget: (v, m) => v == 0
              ? const SizedBox.shrink()
              : Text(
                  _formatNumber(v.toInt()),
                  style: const TextStyle(color: Colors.black87, fontSize: 10),
                ),
        ),
      ),
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, m) {
            if (v.toInt() >= data.labels.length) return const Text('');
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                data.labels[v.toInt()],
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            );
          },
        ),
      ),
    );
  }

  double _calculateMaxY() {
    final allValues = [...data.assigned, ...data.finished];
    if (allValues.isEmpty) return 10;
    final max = allValues.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }

  double _calculateInterval(double maxY) {
    if (maxY <= 10) return 2;
    return (maxY / 5).ceilToDouble();
  }

  String _formatNumber(int value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class ReportFinancialChart extends StatelessWidget {
  final FinancialChartData data;
  final String title;

  const ReportFinancialChart({
    super.key,
    required this.data,
    this.title = 'Collection Overview',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY = _calculateMaxY();
    final interval = _calculateInterval(maxY);

    return AnimatedChartWrapper(
      delay: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const ChartLegend(items: [
              LegendItem(label: 'Collection', color: Colors.indigo),
            ]),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: _buildBarTouchData(),
                  titlesData: _buildTitlesData(interval),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.grey.shade100,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(data.labels.length, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data.collection[index].toDouble(),
            gradient: LinearGradient(
              colors: [Colors.indigo.shade300, Colors.indigo.shade600],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: data.labels.length > 7 ? 12 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  BarTouchData _buildBarTouchData() {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => Colors.blueGrey.shade800,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tooltipRoundedRadius: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          return BarTooltipItem(
            Util.formatMoney(rod.toY),
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          );
        },
      ),
    );
  }

  FlTitlesData _buildTitlesData(double interval) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 45,
          interval: interval,
          getTitlesWidget: (v, m) => v == 0
              ? const SizedBox.shrink()
              : Text(
                  _formatMoney(v.toInt()),
                  style: const TextStyle(color: Colors.black87, fontSize: 10),
                ),
        ),
      ),
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, m) {
            if (v.toInt() >= data.labels.length) return const Text('');
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                data.labels[v.toInt()],
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            );
          },
        ),
      ),
    );
  }

  double _calculateMaxY() {
    if (data.collection.isEmpty) return 1000;
    final max = data.collection.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }

  double _calculateInterval(double maxY) {
    if (maxY <= 10000) return 2000;
    return (maxY / 5).ceilToDouble();
  }

  String _formatMoney(int value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/theme.dart';
import '../models/tech_analytics_models.dart';

final _currFmt =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class AnalyticsRangeSelector extends StatelessWidget {
  final AnalyticsRange selected;
  final ValueChanged<AnalyticsRange> onChanged;
  final VoidCallback? onCustomTap;

  const AnalyticsRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: AnalyticsRange.values.map((range) {
          final isSelected = range == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_rangeLabel(range)),
              selected: isSelected,
              onSelected: (_) {
                if (range == AnalyticsRange.custom) {
                  onCustomTap?.call();
                } else {
                  onChanged(range);
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _rangeLabel(AnalyticsRange range) {
    switch (range) {
      case AnalyticsRange.thisWeek:
        return 'This Week';
      case AnalyticsRange.lastWeek:
        return 'Last Week';
      case AnalyticsRange.thisMonth:
        return 'This Month';
      case AnalyticsRange.lastMonth:
        return 'Last Month';
      case AnalyticsRange.custom:
        return 'Custom';
    }
  }
}

class AnalyticsAggregateCard extends StatelessWidget {
  final TechAnalytics overall;
  final String rangeLabel;

  const AnalyticsAggregateCard({
    super.key,
    required this.overall,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Overall Summary — $rangeLabel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                _StatPill(
                    'Assigned', '${overall.totalOrders}', AppColors.secondary),
                _StatPill('Finished', '${overall.finished}', AppColors.success),
                _StatPill('Cancelled', '${overall.cancelled}', AppColors.error),
                _StatPill('Pending', '${overall.pending}', AppColors.warning),
                _StatPill('Cash', _currFmt.format(overall.cashCollected),
                    Colors.teal),
                _StatPill('GPay', _currFmt.format(overall.gpayCollected),
                    Colors.indigo),
                _StatPill('HC', _currFmt.format(overall.hcCharges),
                    AppColors.primary),
                _StatPill('Disposable',
                    _currFmt.format(overall.disposableCharges), Colors.brown),
                _StatPill('Received', _currFmt.format(overall.totalReceived),
                    AppColors.secondary),
                _StatPill('Tests', '${overall.totalTests}', Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class TechAnalyticsCard extends StatelessWidget {
  final TechAnalytics tech;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExport;

  const TechAnalyticsCard({
    super.key,
    required this.tech,
    required this.isExpanded,
    required this.onTap,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isExpanded ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdAll,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      tech.techName.isNotEmpty
                          ? tech.techName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tech.techName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tech.totalOrders} orders • ${tech.finished} done • ${tech.totalTests} tests',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currFmt.format(tech.totalReceived),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.success,
                        ),
                      ),
                      if (tech.hcCharges > 0)
                        Text(
                          'HC: ${_currFmt.format(tech.hcCharges)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MiniStat('Cash', _currFmt.format(tech.cashCollected),
                          Colors.teal),
                      _MiniStat('GPay', _currFmt.format(tech.gpayCollected),
                          Colors.indigo),
                      _MiniStat('HC', _currFmt.format(tech.hcCharges),
                          AppColors.primary),
                      _MiniStat(
                          'Disposable',
                          _currFmt.format(tech.disposableCharges),
                          Colors.brown),
                      _MiniStat('Discount', _currFmt.format(tech.totalDiscount),
                          AppColors.error),
                    ],
                  ),
                  if (tech.testBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 12),
                     Text(
                      'Test Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TestBreakdownMiniTable(tests: tech.testBreakdown),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.file_download_outlined,
                          size: 16, color: Color(0xFF217346)),
                      label: Text(
                        'Export ${tech.techName} to Excel',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF217346),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF217346)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class TestBreakdownMiniTable extends StatelessWidget {
  final List<TestAggregation> tests;
  const TestBreakdownMiniTable({super.key, required this.tests});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.divider),
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Test',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 1,
                    child: Text('Qty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('Revenue',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          ...tests.take(15).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
              ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        t.investName,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${t.count}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currFmt.format(t.totalRevenue),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              )),
          if (tests.length > 15)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '+${tests.length - 15} more tests',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }
}

class TechAnalyticsDesktopTable extends StatefulWidget {
  final List<TechAnalytics> technicians;
  final void Function(TechAnalytics tech)? onExportTech;
  const TechAnalyticsDesktopTable(
      {super.key, required this.technicians, this.onExportTech});

  @override
  State<TechAnalyticsDesktopTable> createState() =>
      _TechAnalyticsDesktopTableState();
}

class _TechAnalyticsDesktopTableState extends State<TechAnalyticsDesktopTable> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: AppSizes.cardElevation,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: _HeaderText('Technician')),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Orders', align: TextAlign.center)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Done', align: TextAlign.center)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Cancelled', align: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: _HeaderText('Received', align: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: _HeaderText('HC Chrg', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Cash', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('GPay', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Tests', align: TextAlign.center)),
                SizedBox(width: 32),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.technicians.length,
              itemBuilder: (ctx, index) {
                final tech = widget.technicians[index];
                final isExpanded = _expandedIndex == index;

                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedIndex = isExpanded ? null : index;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? (isDark ? AppColors.darkSurfaceAlt : AppColors.tableRowExpanded)
                              : (index % 2 == 0
                                  ? (isDark ? colorScheme.surface : AppColors.tableRowEven)
                                  : (isDark ? AppColors.darkSurfaceAlt : AppColors.tableRowOdd)),
                          border: Border(
                              bottom: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    child: Text(
                                      tech.techName.isNotEmpty
                                          ? tech.techName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      tech.techName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('${tech.totalOrders}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('${tech.finished}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('${tech.cancelled}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: tech.cancelled > 0
                                          ? AppColors.error
                                          : AppColors.textSecondary)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(_currFmt.format(tech.totalReceived),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(_currFmt.format(tech.hcCharges),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(_currFmt.format(tech.cashCollected),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(_currFmt.format(tech.gpayCollected),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text('${tech.totalTests}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            SizedBox(
                              width: 32,
                              child: Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded && tech.testBreakdown.isNotEmpty)
                      Container(
                        color: isDark ? AppColors.darkSurfaceAlt : AppColors.tableRowExpanded,
                        padding: const EdgeInsets.fromLTRB(48, 8, 48, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _MiniStat(
                                    'Billed',
                                    _currFmt.format(tech.totalBilled),
                                    AppColors.secondary),
                                _MiniStat(
                                    'Discount',
                                    _currFmt.format(tech.totalDiscount),
                                    AppColors.error),
                                _MiniStat(
                                    'Disposable',
                                    _currFmt.format(tech.disposableCharges),
                                    Colors.brown),
                                _MiniStat('Pending', '${tech.pending}',
                                    AppColors.warning),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Test Breakdown',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 6),
                            TestBreakdownMiniTable(tests: tech.testBreakdown),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    widget.onExportTech?.call(tech),
                                icon: const Icon(Icons.file_download_outlined,
                                    size: 16, color: Color(0xFF217346)),
                                label: Text(
                                  'Export ${tech.techName} to Excel',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF217346),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFF217346)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _HeaderText(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

class AnalyticsAggregateCardSkeleton extends StatelessWidget {
  const AnalyticsAggregateCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : const Color(0xFFEDF2F7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: const [
                SkeletonBox(width: 18, height: 18),
                SizedBox(width: 8),
                SkeletonBox(width: 180, height: 14),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: List.generate(
                  8,
                  (index) => Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SkeletonBox(width: 50, height: 10),
                            SizedBox(height: 4),
                            SkeletonBox(width: 40, height: 14),
                          ],
                        ),
                      )),
            ),
          ),
        ],
      ),
    );
  }
}

class TechAnalyticsCardSkeleton extends StatelessWidget {
  const TechAnalyticsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonBox(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 14),
                SizedBox(height: 6),
                SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              SkeletonBox(width: 70, height: 14),
              SizedBox(height: 4),
              SkeletonBox(width: 50, height: 10),
            ],
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 16, height: 16),
        ],
      ),
    );
  }
}

class TechAnalyticsDesktopTableSkeleton extends StatelessWidget {
  const TechAnalyticsDesktopTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: AppSizes.cardElevation,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: _HeaderText('Technician')),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Orders', align: TextAlign.center)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Done', align: TextAlign.center)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Cancelled', align: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: _HeaderText('Received', align: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: _HeaderText('HC Chrg', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Cash', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('GPay', align: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: _HeaderText('Tests', align: TextAlign.center)),
                SizedBox(width: 32),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 8,
              itemBuilder: (ctx, index) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? (isDark ? colorScheme.surface : AppColors.tableRowEven)
                        : (isDark ? AppColors.darkSurfaceAlt : AppColors.tableRowOdd),
                    border:
                        Border(bottom: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: const [
                            SkeletonBox(
                                width: 24,
                                height: 24,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12))),
                            SizedBox(width: 8),
                            SkeletonBox(width: 100, height: 12),
                          ],
                        ),
                      ),
                      const Expanded(
                          flex: 1,
                          child: Center(
                              child: SkeletonBox(width: 20, height: 12))),
                      const Expanded(
                          flex: 1,
                          child: Center(
                              child: SkeletonBox(width: 20, height: 12))),
                      const Expanded(
                          flex: 1,
                          child: Center(
                              child: SkeletonBox(width: 16, height: 12))),
                      const Expanded(
                          flex: 2,
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: SkeletonBox(width: 50, height: 12))),
                      const Expanded(
                          flex: 2,
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: SkeletonBox(width: 45, height: 12))),
                      const Expanded(
                          flex: 1,
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: SkeletonBox(width: 35, height: 12))),
                      const Expanded(
                          flex: 1,
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: SkeletonBox(width: 35, height: 12))),
                      const Expanded(
                          flex: 1,
                          child: Center(
                              child: SkeletonBox(width: 20, height: 12))),
                      const SizedBox(
                          width: 32,
                          child: Center(
                              child: SkeletonBox(width: 16, height: 16))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

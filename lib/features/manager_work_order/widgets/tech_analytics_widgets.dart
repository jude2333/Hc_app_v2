import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/theme.dart';
import '../models/tech_analytics_models.dart';

final _currFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

// ---------------------------------------------------------------------------
// Range Selector — Chip row for This Week / Last Week / This Month / etc.
// ---------------------------------------------------------------------------
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
              backgroundColor: AppColors.surfaceAlt,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
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

// ---------------------------------------------------------------------------
// Aggregate Summary Card — Horizontal scrolling stat row
// ---------------------------------------------------------------------------
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
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
          // Stats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                _StatPill('Assigned', '${overall.totalOrders}', AppColors.secondary),
                _StatPill('Finished', '${overall.finished}', AppColors.success),
                _StatPill('Cancelled', '${overall.cancelled}', AppColors.error),
                _StatPill('Pending', '${overall.pending}', AppColors.warning),
                _StatPill('Cash', _currFmt.format(overall.cashCollected), Colors.teal),
                _StatPill('GPay', _currFmt.format(overall.gpayCollected), Colors.indigo),
                _StatPill('HC', _currFmt.format(overall.hcCharges), AppColors.primary),
                _StatPill('Disposable', _currFmt.format(overall.disposableCharges), Colors.brown),
                _StatPill('Received', _currFmt.format(overall.totalReceived), AppColors.secondary),
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

// ---------------------------------------------------------------------------
// Technician Analytics Card — Expandable card for mobile
// ---------------------------------------------------------------------------
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isExpanded ? AppColors.primary : AppColors.border,
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
          // Summary row
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdAll,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
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
                  // Name + orders
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Revenue
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
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Financial row
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
                      _MiniStat(
                          'Discount',
                          _currFmt.format(tech.totalDiscount),
                          AppColors.error),
                    ],
                  ),

                  if (tech.testBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Test Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TestBreakdownMiniTable(tests: tech.testBreakdown),
                  ],

                  // Per-tech export button
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

// ---------------------------------------------------------------------------
// Test Breakdown Table — compact table for expanded view
// ---------------------------------------------------------------------------
class TestBreakdownMiniTable extends StatelessWidget {
  final List<TestAggregation> tests;
  const TestBreakdownMiniTable({super.key, required this.tests});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
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
          // Rows
          ...tests.take(15).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
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
                style: TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop Table Row — for the desktop DataTable view
// ---------------------------------------------------------------------------
class TechAnalyticsDesktopTable extends StatefulWidget {
  final List<TechAnalytics> technicians;
  final void Function(TechAnalytics tech)? onExportTech;
  const TechAnalyticsDesktopTable({super.key, required this.technicians, this.onExportTech});

  @override
  State<TechAnalyticsDesktopTable> createState() =>
      _TechAnalyticsDesktopTableState();
}

class _TechAnalyticsDesktopTableState extends State<TechAnalyticsDesktopTable> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppSizes.cardElevation,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: _HeaderText('Technician')),
                Expanded(flex: 1, child: _HeaderText('Orders', align: TextAlign.center)),
                Expanded(flex: 1, child: _HeaderText('Done', align: TextAlign.center)),
                Expanded(flex: 1, child: _HeaderText('Cancelled', align: TextAlign.center)),
                Expanded(flex: 2, child: _HeaderText('Received', align: TextAlign.right)),
                Expanded(flex: 2, child: _HeaderText('HC Chrg', align: TextAlign.right)),
                Expanded(flex: 1, child: _HeaderText('Cash', align: TextAlign.right)),
                Expanded(flex: 1, child: _HeaderText('GPay', align: TextAlign.right)),
                Expanded(flex: 1, child: _HeaderText('Tests', align: TextAlign.center)),
                SizedBox(width: 32),
              ],
            ),
          ),
          // Data rows
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isExpanded
                              ? AppColors.tableRowExpanded
                              : (index % 2 == 0
                                  ? AppColors.tableRowEven
                                  : AppColors.tableRowOdd),
                          border: Border(
                              bottom: BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.15),
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
                              child: Text(
                                  _currFmt.format(tech.totalReceived),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                  _currFmt.format(tech.hcCharges),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                  _currFmt.format(tech.cashCollected),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                  _currFmt.format(tech.gpayCollected),
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
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanded test breakdown
                    if (isExpanded && tech.testBreakdown.isNotEmpty)
                      Container(
                        color: AppColors.tableRowExpanded,
                        padding: const EdgeInsets.fromLTRB(48, 8, 48, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Financial summary row
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _MiniStat('Billed', _currFmt.format(tech.totalBilled), AppColors.secondary),
                                _MiniStat('Discount', _currFmt.format(tech.totalDiscount), AppColors.error),
                                _MiniStat('Disposable', _currFmt.format(tech.disposableCharges), Colors.brown),
                                _MiniStat('Pending', '${tech.pending}', AppColors.warning),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Test Breakdown',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            TestBreakdownMiniTable(
                                tests: tech.testBreakdown),
                            const SizedBox(height: 12),
                            // Per-tech export button
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => widget.onExportTech?.call(tech),
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
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: AppColors.textPrimary,
      ),
    );
  }
}

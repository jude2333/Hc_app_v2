import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';

class HCStepBilling extends ConsumerStatefulWidget {
  final String workOrderId;

  const HCStepBilling({Key? key, required this.workOrderId}) : super(key: key);

  @override
  ConsumerState<HCStepBilling> createState() => _HCStepBillingState();
}

class _HCStepBillingState extends ConsumerState<HCStepBilling> {
  late TextEditingController _discountController;
  late TextEditingController _hcChargesController;
  late TextEditingController _dispChargesController;
  late TextEditingController _testDiscountController;

  int? _expandedTestIndex;
  bool _testDiscountIsFlat = false;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(text: '0');
    _hcChargesController = TextEditingController(text: '50');
    _dispChargesController = TextEditingController(text: '30');
    _testDiscountController = TextEditingController();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _hcChargesController.dispose();
    _dispChargesController.dispose();
    _testDiscountController.dispose();
    super.dispose();
  }

  void _onDiscountChanged(String value) {
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    final state = ref.read(hcProcessProvider(widget.workOrderId));

    final parsed = double.tryParse(value) ?? 0;

    // Validation: clamp to safe range
    double safeVal;
    if (state.isDiscountFlat) {
      // Flat mode: can't exceed bill amount
      safeVal = parsed.clamp(0, state.billAmount);
    } else {
      // Percentage mode: 0-50%
      safeVal = parsed.clamp(0, 50);
    }

    notifier.setDiscount(safeVal);
    controller.calculateDiscount();
  }

  void _onDiscountModeChanged(bool isFlat) {
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    notifier.setDiscountMode(isFlat);
    _discountController.text = '0';
    controller.calculateDiscount();
  }

  void _onHcChargesChanged(String? value) {
    if (value == null) return;
    _hcChargesController.text = value;
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    notifier.setHcCharges(double.tryParse(value) ?? 0);
    controller.calculateDiscount();
  }

  void _onDispChargesChanged(String? value) {
    if (value == null) return;
    _dispChargesController.text = value;
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    notifier.setDisposableCharges(double.tryParse(value) ?? 0);
    controller.calculateDiscount();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    final bool areChargesEnabled = state.creditClient ? state.cghsPrice : true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Test Amount Header ──
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Amount: ₹${state.billAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total for ${state.selectedTests.length} test(s) — before charges & discount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (state.creditClient && state.cghsPrice)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'CGHS Credit — Only HC & Disposable Charges apply',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  )
                else if (state.creditClient)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Credit Client — No Payment Required',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Credit Client Toggle ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: state.creditClient
                ? Colors.indigo.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.creditClient
                  ? Colors.indigo.shade200
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Switch(
                value: state.creditClient,
                onChanged: (v) {
                  final notifier =
                      ref.read(hcProcessProvider(widget.workOrderId).notifier);
                  final controller =
                      ref.read(hcProcessControllerProvider(widget.workOrderId));
                  notifier.setCreditClient(v);
                  controller.onCreditChange();
                },
                activeColor: Colors.indigo,
              ),
              Text(
                'Credit Client',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: state.creditClient
                      ? Colors.indigo.shade700
                      : Colors.grey.shade600,
                ),
              ),
              if (state.creditClient) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Credit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Individual Test Discount Section ──
        if (state.selectedTests.isNotEmpty) ...[
          _buildTestDiscountList(state, areChargesEnabled),
          const SizedBox(height: 12),
        ],

        // ── Discount Section with Mode Toggle ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Discount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Segmented toggle: % or ₹
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(
                          label: '%',
                          tooltip: 'Percentage',
                          isSelected: !state.isDiscountFlat,
                          enabled: areChargesEnabled,
                          onTap: () => _onDiscountModeChanged(false),
                        ),
                        _buildModeButton(
                          label: '₹',
                          tooltip: 'Flat Amount',
                          isSelected: state.isDiscountFlat,
                          enabled: areChargesEnabled,
                          onTap: () => _onDiscountModeChanged(true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _discountController,
                enabled: areChargesEnabled,
                onChanged: _onDiscountChanged,
                decoration: InputDecoration(
                  labelText: state.isDiscountFlat
                      ? 'Discount Amount'
                      : 'Discount Percentage',
                  hintText: state.isDiscountFlat ? 'e.g. 200' : 'e.g. 10',
                  suffixText: state.isDiscountFlat ? '₹' : '%',
                  suffixStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color:
                        areChargesEnabled ? Colors.teal.shade700 : Colors.grey,
                  ),
                  border: const OutlineInputBorder(),
                  helperText: state.isDiscountFlat
                      ? 'Max: ₹${state.billAmount.toStringAsFixed(0)}'
                      : 'Max: 50%',
                  helperStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── HC Charges Dropdown ──
        DropdownButtonFormField<String>(
          value: _hcChargesController.text,
          onChanged: areChargesEnabled ? _onHcChargesChanged : null,
          decoration: const InputDecoration(
            labelText: 'Home Collection Charges',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee, size: 16),
          ),
          items: ['0', '25', '50', '100', '150', '200', '250']
              .map((label) => DropdownMenuItem(
                    value: label,
                    child: Text(label),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),

        // ── Disposable Charges Dropdown ──
        DropdownButtonFormField<String>(
          value: _dispChargesController.text,
          onChanged: areChargesEnabled ? _onDispChargesChanged : null,
          decoration: const InputDecoration(
            labelText: 'Disposable Charges',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee, size: 16),
          ),
          items: ['0', '10', '20', '30', '40', '50', '100']
              .map((label) => DropdownMenuItem(
                    value: label,
                    child: Text(label),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),

        // ── Detailed Summary Card ──
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Bill Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Test amount (sum of original prices before individual discounts)
                _breakdownRow(
                  'Test Amount',
                  '₹${_originalTestTotal(state).toStringAsFixed(0)}',
                ),

                // Individual test discounts
                if (_totalTestDiscount(state) > 0)
                  _breakdownRow(
                    'Test Discounts',
                    '- ₹${_totalTestDiscount(state).toStringAsFixed(0)}',
                    valueColor: Colors.purple.shade600,
                  ),

                // Subtotal after test discounts (= billAmount)
                if (_totalTestDiscount(state) > 0)
                  _breakdownRow(
                    'Subtotal',
                    '₹${state.billAmount.toStringAsFixed(0)}',
                  ),

                // Overall discount
                if (state.discount > 0) ...[
                  _breakdownRow(
                    state.isDiscountFlat
                        ? 'Overall Discount (₹${state.discount.toStringAsFixed(0)} off)'
                        : 'Overall Discount (${state.discount.toStringAsFixed(0)}% off)',
                    '- ₹${(state.billAmount - state.amountAfterDiscount).toStringAsFixed(0)}',
                    valueColor: Colors.red.shade600,
                  ),
                  _breakdownRow(
                    'After Discount',
                    '₹${state.amountAfterDiscount.toStringAsFixed(0)}',
                  ),
                ],

                // Extra charges
                if (state.hcCharges > 0)
                  _breakdownRow(
                    'Home Collection Charges',
                    '+ ₹${state.hcCharges.toStringAsFixed(0)}',
                    valueColor: Colors.orange.shade700,
                  ),
                if (state.disposableCharges > 0)
                  _breakdownRow(
                    'Disposable Charges',
                    '+ ₹${state.disposableCharges.toStringAsFixed(0)}',
                    valueColor: Colors.orange.shade700,
                  ),

                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 1.5),
                const SizedBox(height: 8),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount to Collect',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${state.amountReceived.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required String label,
    required String tooltip,
    required bool isSelected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled && !isSelected ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: !enabled
                  ? Colors.grey.shade400
                  : isSelected
                      ? Colors.white
                      : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable row for bill breakdown items
  Widget _breakdownRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Individual Test Discount Helpers ──

  /// Build the expandable test list with per-test discount controls
  Widget _buildTestDiscountList(HCProcessState state, bool enabled) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined,
                  size: 16, color: Colors.purple.shade600),
              const SizedBox(width: 6),
              Text(
                'Test-wise Discount',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.purple.shade700,
                ),
              ),
              const Spacer(),
              if (_totalTestDiscount(state) > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    '-₹${_totalTestDiscount(state).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...state.selectedTests.asMap().entries.map((entry) {
            final index = entry.key;
            final test = entry.value;
            final isExpanded = _expandedTestIndex == index;

            // Prices
            final baseCost =
                double.tryParse(test['base_cost']?.toString() ?? '0') ?? 0;
            final cghsCost =
                double.tryParse(test['cghs_price']?.toString() ?? '0') ?? 0;
            final activePrice =
                (state.cghsPrice && cghsCost > 0) ? cghsCost : baseCost;

            // Discount info
            final discountedPrice =
                double.tryParse(test['discounted_price']?.toString() ?? '');
            final discountValue =
                double.tryParse(test['discount_value']?.toString() ?? '');
            final discountType = test['discount_type']?.toString();
            final hasDiscount =
                discountedPrice != null && discountValue != null;

            return Column(
              children: [
                InkWell(
                  onTap: enabled
                      ? () {
                          setState(() {
                            if (isExpanded) {
                              _expandedTestIndex = null;
                            } else {
                              _expandedTestIndex = index;
                              _testDiscountIsFlat = discountType == 'flat';
                              _testDiscountController.text =
                                  discountValue?.toStringAsFixed(0) ?? '';
                            }
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            test['invest_name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasDiscount) ...[
                          // Discount badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              discountType == 'flat'
                                  ? '-₹${discountValue.toStringAsFixed(0)}'
                                  : '-${discountValue.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Strikethrough original
                          Text(
                            '₹${activePrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Discounted price
                          Text(
                            '₹${discountedPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ] else
                          Text(
                            '₹${activePrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Expanded discount input
                if (isExpanded)
                  _buildTestDiscountInput(index, activePrice, enabled),
                if (index < state.selectedTests.length - 1)
                  Divider(height: 1, color: Colors.grey.shade200),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Inline discount input for an expanded test
  Widget _buildTestDiscountInput(int index, double activePrice, bool enabled) {
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 4, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Mode toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      label: '%',
                      tooltip: 'Percentage',
                      isSelected: !_testDiscountIsFlat,
                      enabled: enabled,
                      onTap: () {
                        setState(() {
                          _testDiscountIsFlat = false;
                          _testDiscountController.clear();
                        });
                      },
                    ),
                    _buildModeButton(
                      label: '₹',
                      tooltip: 'Flat Amount',
                      isSelected: _testDiscountIsFlat,
                      enabled: enabled,
                      onTap: () {
                        setState(() {
                          _testDiscountIsFlat = true;
                          _testDiscountController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Input field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _testDiscountController,
                    enabled: enabled,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: _testDiscountIsFlat ? 'eg. 100' : 'eg. 10',
                      suffixText: _testDiscountIsFlat ? '₹' : '%',
                      suffixStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.purple.shade600,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Apply button
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: enabled
                      ? () {
                          final val =
                              double.tryParse(_testDiscountController.text) ??
                                  0;
                          if (val <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Enter a positive discount value'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                            return;
                          }

                          // Validate
                          if (_testDiscountIsFlat && val > activePrice) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Discount cannot exceed ₹${activePrice.toStringAsFixed(0)}'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                            return;
                          }
                          if (!_testDiscountIsFlat && val > 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Percentage cannot exceed 100%'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                            return;
                          }

                          notifier.applyTestDiscount(
                              index, val, _testDiscountIsFlat);
                          controller.calculateDiscount();
                          setState(() => _expandedTestIndex = null);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _testDiscountIsFlat
                    ? 'Max: ₹${activePrice.toStringAsFixed(0)}'
                    : 'Max: 100%',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const Spacer(),
              // Clear button (if discount exists)
              TextButton(
                onPressed: enabled
                    ? () {
                        notifier.clearTestDiscount(index);
                        controller.calculateDiscount();
                        setState(() {
                          _expandedTestIndex = null;
                          _testDiscountController.clear();
                        });
                      }
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? Colors.red.shade400 : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sum of original prices (ignoring individual discounts)
  double _originalTestTotal(HCProcessState state) {
    double total = 0;
    for (final test in state.selectedTests) {
      final baseCost =
          double.tryParse(test['base_cost']?.toString() ?? '0') ?? 0;
      final cghsCost =
          double.tryParse(test['cghs_price']?.toString() ?? '0') ?? 0;
      total += (state.cghsPrice && cghsCost > 0) ? cghsCost : baseCost;
    }
    return total;
  }

  /// Sum of all individual test discount amounts
  double _totalTestDiscount(HCProcessState state) {
    return _originalTestTotal(state) - state.billAmount;
  }
}

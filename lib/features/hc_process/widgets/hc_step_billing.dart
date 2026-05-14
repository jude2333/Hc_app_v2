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

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(text: '0');
    _hcChargesController = TextEditingController(text: '50');
    _dispChargesController = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    _discountController.dispose();
    _hcChargesController.dispose();
    _dispChargesController.dispose();
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
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  )
                else if (state.creditClient)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Credit Client — No Payment Required',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, size: 18, color: Colors.blue.shade700),
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

                // Test amount
                _breakdownRow(
                  'Test Amount',
                  '₹${state.billAmount.toStringAsFixed(0)}',
                ),

                // Discount
                if (state.discount > 0) ...[
                  _breakdownRow(
                    state.isDiscountFlat
                        ? 'Discount (₹${state.discount.toStringAsFixed(0)} off)'
                        : 'Discount (${state.discount.toStringAsFixed(0)}% off)',
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
}

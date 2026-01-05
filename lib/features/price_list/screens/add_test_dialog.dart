import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anderson_crm_flutter/util.dart';

import 'package:anderson_crm_flutter/features/price_list/price_list.dart';

class AddTestDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> workOrder;
  final bool useCghsPrice;

  const AddTestDialog({
    Key? key,
    required this.workOrder,
    required this.useCghsPrice,
  }) : super(key: key);

  @override
  ConsumerState<AddTestDialog> createState() => _AddTestDialogState();
}

class _AddTestDialogState extends ConsumerState<AddTestDialog> {
  List<Map<String, dynamic>> _selectedTests = [];
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedTests();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isFirstLoad && _selectedTests.isEmpty) {
        _showSearchSheet();
      }
      _isFirstLoad = false;
    });
  }

  Future<void> _loadSelectedTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? selectedStr = prefs.getString('selected_tests');
      if (selectedStr != null && selectedStr.isNotEmpty) {
        List<dynamic> decoded = jsonDecode(selectedStr);
        if (mounted) {
          setState(() {
            _selectedTests =
                decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading selected tests: $e');
    }
  }

  Future<void> _saveSelectedTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_tests', jsonEncode(_selectedTests));
    } catch (e) {
      debugPrint('Error saving selected tests: $e');
    }
  }

  void _addTest(Map<String, dynamic> item) {
    final isDuplicate = _selectedTests.any((test) =>
        (test['_id'] != null && test['_id'] == item['_id']) ||
        (test['invest_id'] == item['invest_id']));

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Test already added'),
            duration: Duration(seconds: 1)),
      );
      return;
    }

    setState(() {
      _selectedTests.add(item);
    });
    _saveSelectedTests();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${item['invest_name']} added'),
          duration: const Duration(milliseconds: 500)),
    );
  }

  void _removeTest(int index) {
    setState(() {
      _selectedTests.removeAt(index);
    });
    _saveSelectedTests();
  }

  double _calculateTotal() {
    double total = 0;
    for (var test in _selectedTests) {
      if (widget.useCghsPrice) {
        double cghsPrice =
            double.tryParse(test['cghs_price']?.toString() ?? '0') ?? 0;
        double baseCost =
            double.tryParse(test['base_cost']?.toString() ?? '0') ?? 0;
        total += (cghsPrice > 0) ? cghsPrice : baseCost;
      } else {
        total += double.tryParse(test['base_cost']?.toString() ?? '0') ?? 0;
      }
    }
    return total;
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchTestSheet(
        useCghsPrice: widget.useCghsPrice,
        onSelect: _addTest,
      ),
    );
  }

  void _saveAndClose() {
    if (_selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one test')),
      );
      return;
    }

    final appTime = (widget.workOrder['visit_time'] ?? '00:00')
        .toString()
        .replaceAll(':', '_');
    String mobile = '0000000000';

    if (widget.workOrder['doc'] != null) {
      try {
        final docData = (widget.workOrder['doc'] is String)
            ? jsonDecode(widget.workOrder['doc'])
            : widget.workOrder['doc'];
        mobile = docData['mobile']?.toString() ?? '0000000000';
      } catch (_) {}
    } else if (widget.workOrder['mobile'] != null) {
      mobile = widget.workOrder['mobile'].toString();
    }

    final fname = 'proforma_${mobile}_$appTime.pdf';
    final proformaPath =
        'homecollection/proforma/${Util.getTodayStringForFolderCreation()}/$fname';

    Navigator.of(context).pop({
      'testitems': _selectedTests,
      'total': _calculateTotal(),
      'proformalocation': proformaPath,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selected Tests',
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(
                '${widget.workOrder['patient_name'] ?? 'Patient'} ${widget.useCghsPrice ? '(CGHS)' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _showSearchSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add Test',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedTests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_services_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No tests added yet',
                            style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showSearchSheet,
                          icon: const Icon(Icons.search),
                          label: const Text('Search Tests'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white),
                        )
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _selectedTests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final test = _selectedTests[index];
                      final price = double.tryParse(
                              test['base_cost']?.toString() ?? '0') ??
                          0;
                      final cghsPrice = double.tryParse(
                              test['cghs_price']?.toString() ?? '0') ??
                          0;

                      final displayPrice = widget.useCghsPrice && cghsPrice > 0
                          ? cghsPrice
                          : price;
                      final isCghsApplied =
                          widget.useCghsPrice && cghsPrice > 0;

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          title: Text(test['invest_name'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(test['dept_name'] ?? 'General',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(Util.formatMoney(displayPrice),
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  if (isCghsApplied)
                                    const Text('CGHS Rate',
                                        style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))
                                  else if (widget.useCghsPrice)
                                    const Text('Standard',
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _removeTest(index),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        Util.formatMoney(_calculateTotal()),
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 24),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saveAndClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save & Continue',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SearchTestSheet extends ConsumerWidget {
  final bool useCghsPrice;
  final Function(Map<String, dynamic>) onSelect;

  const _SearchTestSheet({required this.useCghsPrice, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(priceListProvider);
    final notifier = ref.read(priceListProvider.notifier);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search (Name, Dept, >500)',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => notifier.search(val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const _HeaderCell('Department', flex: 2),
                const _HeaderCell('Investigation', flex: 3),
                const _HeaderCell('Price', flex: 1),
                if (useCghsPrice) const _HeaderCell('CGHS', flex: 1),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : state.items.isEmpty
                    ? const Center(
                        child: Text('No items found',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          final price = item.baseCost;
                          final cghsPrice = item.cghsPrice;

                          return InkWell(
                            onTap: () => onSelect(item.toDisplayMap()),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  _DataCell(item.deptName, flex: 2),
                                  _DataCell(item.investName,
                                      flex: 3, isBold: true),
                                  _DataCell(Util.formatMoney(price),
                                      flex: 1, color: Colors.green),
                                  if (useCghsPrice)
                                    _DataCell(Util.formatMoney(cghsPrice),
                                        flex: 1, color: Colors.blue),
                                ],
                              ),
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

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87)),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isBold;
  final Color? color;
  const _DataCell(this.text,
      {required this.flex, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: color ?? Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

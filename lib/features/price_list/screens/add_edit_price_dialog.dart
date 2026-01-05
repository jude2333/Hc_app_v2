import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/features/price_list/price_list.dart';

class AddEditPriceDialog extends ConsumerStatefulWidget {
  final PriceListItem? existingItem;
  const AddEditPriceDialog({Key? key, this.existingItem}) : super(key: key);

  @override
  ConsumerState<AddEditPriceDialog> createState() => _AddEditPriceDialogState();
}

class _AddEditPriceDialogState extends ConsumerState<AddEditPriceDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedDept;
  final _deptIdController = TextEditingController();

  final _investIdController = TextEditingController();
  final _investNameController = TextEditingController();

  final _baseCostController = TextEditingController();
  final _minCostController = TextEditingController();
  final _cghsPriceController = TextEditingController();

  bool get isEdit => widget.existingItem != null;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    if (isEdit) {
      final item = widget.existingItem!;
      setState(() {
        _selectedDept = item.deptName;
        _deptIdController.text = item.deptId;
        _investIdController.text = item.investId;
        _investNameController.text = item.investName;
        _baseCostController.text = item.baseCost.toString();
        _minCostController.text = item.minCost.toString();
        _cghsPriceController.text = item.cghsPrice.toString();
      });
    }
  }

  @override
  void dispose() {
    _deptIdController.dispose();
    _investIdController.dispose();
    _investNameController.dispose();
    _baseCostController.dispose();
    _minCostController.dispose();
    _cghsPriceController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final base = double.tryParse(_baseCostController.text) ?? 0;
    final min = double.tryParse(_minCostController.text) ?? 0;
    final cghs = double.tryParse(_cghsPriceController.text) ?? 0;

    if (min > base) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Min. Cost Cannot Be Greater Than Base Cost.'),
          backgroundColor: Colors.orange));
      return;
    }

    if (base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter Base Cost'),
          backgroundColor: Colors.orange));
      return;
    }

    if (cghs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter CGHS Price'),
          backgroundColor: Colors.orange));
      return;
    }

    final formData = {
      'dept_name': _selectedDept,
      'dept_id': _deptIdController.text,
      'invest_id': _investIdController.text,
      'invest_name': _investNameController.text,
      'base_cost': base,
      'min_cost': min,
      'cghs_price': cghs,
    };

    final notifier = ref.read(priceListProvider.notifier);
    String result;

    if (isEdit) {
      result = await notifier.updateTest(formData, widget.existingItem!);
    } else {
      result = await notifier.addTest(formData);
    }

    if (mounted) {
      if (result == "OK") {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(isEdit ? 'Updated Successfully' : 'Created Successfully'),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceListProvider);

    return AlertDialog(
      backgroundColor: Colors.white,
      title: Chip(
        label: Text(isEdit ? 'Edit Test' : 'Add New Test',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: state.deptNames.contains(_selectedDept)
                            ? _selectedDept
                            : null,
                        decoration: const InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder()),
                        items: state.deptNames
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: isEdit
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedDept = v;

                                  _deptIdController.text =
                                      state.deptMap[v?.toLowerCase()] ?? '';
                                });
                              },
                        validator: (v) =>
                            v == null ? 'Please Choose Department' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _deptIdController,
                        decoration: const InputDecoration(
                            labelText: 'Dept ID', border: OutlineInputBorder()),
                        enabled: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildComboBox(
                        controller: _investIdController,
                        label: 'Invest. ID',
                        options: state.investIds,
                        enabled: !isEdit,
                        onSelected: (val) {
                          final name = state.investIdToName[val];
                          if (name != null) {
                            setState(() {
                              _investNameController.text = name;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildComboBox(
                        controller: _investNameController,
                        label: 'Invest. Name',
                        options: state.investNames,
                        enabled: !isEdit,
                        onSelected: (val) {
                          final id = state.investNameToId[val];
                          if (id != null) {
                            setState(() {
                              _investIdController.text = id;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _baseCostController,
                        decoration: const InputDecoration(
                            labelText: 'Base Price',
                            prefixText: '₹ ',
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _minCostController,
                        decoration: const InputDecoration(
                            labelText: 'Min Price',
                            prefixText: '₹ ',
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _cghsPriceController,
                        decoration: const InputDecoration(
                            labelText: 'CGHS Price',
                            prefixText: '₹ ',
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: state.isLoading ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(state.isLoading ? 'Saving...' : 'Save')),
      ],
    );
  }

  Widget _buildComboBox({
    required TextEditingController controller,
    required String label,
    required List<String> options,
    required Function(String) onSelected,
    bool enabled = true,
  }) {
    if (!enabled) {
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        enabled: false,
      );
    }

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final text = textEditingValue.text.toLowerCase().trim();

        if (text.isEmpty) {
          return options.take(50);
        }

        return options.where((option) {
          return option.toLowerCase().contains(text);
        }).take(50);
      },
      onSelected: (String selection) {
        controller.text = selection;
        onSelected(selection);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        textEditingController.text = controller.text;
        textEditingController.addListener(() {
          controller.text = textEditingController.text;
        });

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          onChanged: (value) {
            controller.text = value;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        option,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

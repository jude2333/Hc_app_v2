import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

class EditWorkOrderDialog extends ConsumerStatefulWidget {
  final WorkOrder workOrder;

  const EditWorkOrderDialog({Key? key, required this.workOrder})
      : super(key: key);

  @override
  ConsumerState<EditWorkOrderDialog> createState() =>
      _EditWorkOrderDialogState();
}

class _EditWorkOrderDialogState extends ConsumerState<EditWorkOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _mobileController;

  // State
  String _salutation = 'Mr';
  String _gender = 'Male';

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    String fullName = widget.workOrder.patientName;
    String nameOnly = fullName;

    if (fullName.contains('.')) {
      final parts = fullName.split('.');
      _salutation = parts[0].trim();
      nameOnly = parts.sublist(1).join('.').trim();
    }

    if (!['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr'].contains(_salutation)) {
      _salutation = 'Mr';
      nameOnly = fullName;
    }
    _nameController = TextEditingController(text: nameOnly);
    _ageController = TextEditingController(text: widget.workOrder.age);
    _mobileController = TextEditingController(text: widget.workOrder.mobile);
    _gender =
        widget.workOrder.gender.isNotEmpty ? widget.workOrder.gender : 'Male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _onSalutationChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _salutation = newValue;
      if (_salutation == 'Ms' || _salutation == 'Mrs') {
        _gender = 'Female';
      } else if (_salutation == 'Mr') {
        _gender = 'Male';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final provider = ref.read(workOrderProvider);
      final currentUser =
          storage.getFromSession('logged_in_emp_name') ?? 'Technician';

      final finalName =
          '$_salutation. ${Util.toTitleCase(_nameController.text.trim())}';

      final updatedDocMap =
          Map<String, dynamic>.from(widget.workOrder.parsedDoc);
      updatedDocMap['name'] = finalName;
      updatedDocMap['age'] = _ageController.text.trim();
      updatedDocMap['gender'] = _gender;
      updatedDocMap['mobile'] = _mobileController.text.trim();
      updatedDocMap['updated_at'] = DateTime.now().toIso8601String();

      final updatedWorkOrder = widget.workOrder.copyWith(
        patientName: finalName,
        lastUpdatedBy: currentUser,
        lastUpdatedAt: DateTime.now(),
        doc: jsonEncode(updatedDocMap),
      );

      final success = await provider.updateWorkOrder(updatedWorkOrder,
          customDoc: updatedDocMap);

      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      debugPrint('Error saving: $e');
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Calculation
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(24),
      title: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Edit Patient Details',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: isWeb ? 450 : width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _salutation,
                        isExpanded: true,
                        decoration: _inputDecoration('Salutation'),
                        items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: _onSalutationChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _nameController,
                        decoration:
                            _inputDecoration('Name', icon: Icons.person),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (v.length > 30) return 'Max 30 chars';
                          return null;
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
                      flex: 3,
                      child: TextFormField(
                        controller: _ageController,
                        decoration: _inputDecoration('Age', icon: Icons.cake),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        isExpanded: true,
                        decoration: _inputDecoration('Gender'),
                        items: ['Male', 'Female', 'Other']
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: _inputDecoration('Mobile', icon: Icons.phone),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length != 10) return 'Must be 10 digits';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          icon != null ? Icon(icon, color: Colors.orange, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      isDense: true,
    );
  }
}

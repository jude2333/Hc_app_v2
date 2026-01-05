import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/work_order.dart';
import '../../../providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../../services/postgresService.dart';
import '../../../util.dart';
import '../../../config/settings.dart';

final _b2bClientsPod = StateProvider<List<Map<String, dynamic>>>((_) => []);

class AddWorkOrderPageMobile extends ConsumerStatefulWidget {
  final WorkOrder? existingWorkOrder;
  final WorkOrder? copyFrom;

  const AddWorkOrderPageMobile({
    Key? key,
    this.existingWorkOrder,
    this.copyFrom,
  }) : super(key: key);

  @override
  ConsumerState<AddWorkOrderPageMobile> createState() =>
      _AddWorkOrderPageMobileState();
}

class _AddWorkOrderPageMobileState
    extends ConsumerState<AddWorkOrderPageMobile> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _freeTextController = TextEditingController();
  final TextEditingController _cancelReasonController = TextEditingController();

  String _collectionDate = '';
  TimeOfDay? _collectionTime;
  String _salutation = 'Mr';
  String _gender = 'Male';
  bool _vip = false;
  bool _urgent = false;
  int _credit = 0;
  String _creditSelect = 'None';
  bool _b2b = false;

  bool _isCancelled = false;

  bool _msgSms = true;
  bool _msgWhatsapp = true;
  bool _msgEmail = true;

  XFile? _prescriptionImage;
  String _prescriptionPath = '';

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _hasAttemptedValidation = false;

  int _selectedB2BClientId = 0;
  String _selectedB2BClientName = '';

  List<String> _suitableDates = [];

  bool get isEditMode => widget.existingWorkOrder != null;
  bool get isCopyMode => widget.copyFrom != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isEditMode) {
        _loadData(widget.existingWorkOrder!, isCopy: false);
      } else if (isCopyMode) {
        _loadData(widget.copyFrom!, isCopy: true);
      } else {
        _initializeDates();
      }
    });
  }

  void _initializeDates() {
    if (!mounted) return;
    setState(() {
      final today =
          Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
      for (int i = 0; i <= 9; i++) {
        final date = today.add(Duration(days: i));
        _suitableDates.add(DateFormat('EEEE d MMM yyyy').format(date));
      }
      _collectionDate = _suitableDates.isNotEmpty ? _suitableDates[0] : '';
      _isInitialized = true;
    });
  }

  void _loadData(WorkOrder wo, {required bool isCopy}) {
    final nameParts = wo.patientName.split('. ');
    _salutation = nameParts.length > 1 ? nameParts[0] : 'Mr';
    _nameController.text = nameParts.length > 1 ? nameParts[1] : wo.patientName;

    _ageController.text = wo.age;
    _emailController.text = wo.email == 'NA' ? '' : wo.email;
    _mobileController.text = wo.mobile;
    _addressController.text = wo.address;
    _pincodeController.text = wo.pincode;
    _doctorController.text = wo.doctorName;
    _freeTextController.text = wo.freeText;

    _gender = wo.gender;
    _vip = wo.vip;
    _urgent = wo.urgent;
    _credit = wo.credit;
    _creditSelect = _credit == 1 ? 'Credit' : (_credit == 2 ? 'Trial' : 'None');

    _selectedB2BClientId = wo.b2bClientId ?? 0;
    _selectedB2BClientName = wo.b2bClientName;
    _b2b = _selectedB2BClientId > 0;

    if (!isCopy) {
      _isCancelled = wo.status == 'cancelled';
      _cancelReasonController.text = wo.parsedDoc['cancel_reason'] ?? '';
    }

    if (isCopy) {
      _initializeDates();
      _collectionTime = null;
    } else {
      _initializeDatesForEdit(wo.visitDate);
      final timeParts = wo.visitTime.split(':');
      if (timeParts.length == 2) {
        _collectionTime = TimeOfDay(
            hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      }
    }

    if (!isCopy) {
      _prescriptionPath = wo.prescriptionPath;
    }

    _msgSms = wo.sendSms;
    _msgWhatsapp = wo.sendWhatsapp;
    _msgEmail = wo.sendEmail;

    setState(() => _isInitialized = true);
  }

  void _initializeDatesForEdit(DateTime existingDate) {
    if (!mounted) return;
    setState(() {
      final today =
          Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
      for (int i = 0; i <= 9; i++) {
        final date = today.add(Duration(days: i));
        _suitableDates.add(DateFormat('EEEE d MMM yyyy').format(date));
      }
      final formattedExisting =
          DateFormat('EEEE d MMM yyyy').format(existingDate);
      if (!_suitableDates.contains(formattedExisting)) {
        _suitableDates.insert(0, formattedExisting);
      }
      _collectionDate = formattedExisting;
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = 'New Work Order';
    if (isEditMode) title = 'Edit Work Order';
    if (isCopyMode) title = 'Copy Work Order';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
            tooltip: 'Notification Settings',
          ),
        ],
      ),
      body: _isInitialized
          ? Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (isCopyMode) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.orange.shade200)),
                          child: Row(
                            children: const [
                              Icon(Icons.copy, color: Colors.orange),
                              SizedBox(width: 12),
                              Expanded(
                                  child: Text(
                                      'You are creating a copy. Please select a new date and time.',
                                      style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold))),
                            ],
                          ),
                        )
                      ],
                      _buildDateTimeSection(),
                      const SizedBox(height: 20),
                      _buildNameSection(),
                      const SizedBox(height: 20),
                      _buildContactSection(),
                      const SizedBox(height: 20),
                      _buildDoctorSection(),
                      const SizedBox(height: 32),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 3)),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDateTimeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _collectionDate.isNotEmpty ? _collectionDate : null,
              decoration: InputDecoration(
                  labelText: 'Collection Date',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.calendar_today, size: 20)),
              items: _suitableDates
                  .map((date) =>
                      DropdownMenuItem(value: date, child: Text(date)))
                  .toList(),
              onChanged: (value) => setState(() => _collectionDate = value!),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectTime(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color:
                            _hasAttemptedValidation && _collectionTime == null
                                ? Colors.red
                                : Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: _collectionTime == null
                            ? Colors.grey
                            : Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            _collectionTime?.format(context) ??
                                'Select Collection Time',
                            style: TextStyle(
                                fontSize: 16,
                                color: _collectionTime == null
                                    ? Colors.grey
                                    : Colors.black))),
                    if (_collectionTime != null)
                      IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () =>
                              setState(() => _collectionTime = null)),
                  ],
                ),
              ),
            ),
            if (_hasAttemptedValidation && _collectionTime == null)
              Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: Text('Please select collection time',
                      style:
                          TextStyle(color: Colors.red.shade600, fontSize: 12))),
            const SizedBox(height: 16),
            _buildImageUpload(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUpload() {
    if (_prescriptionImage == null) {
      return ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Upload Prescription'),
          onPressed: _showImageSourceDialog,
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8)),
              child: kIsWeb
                  ? Image.network(_prescriptionImage!.path, fit: BoxFit.cover)
                  : Image.file(File(_prescriptionImage!.path),
                      fit: BoxFit.cover))),
      const SizedBox(height: 8),
      TextButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Change Image'),
          onPressed: _showImageSourceDialog),
    ]);
  }

  Widget _buildNameSection() {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Patient Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                        value: _salutation.isEmpty ? null : _salutation,
                        decoration: InputDecoration(
                            labelText: 'Title',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _salutation = v!;
                            _updateGenderFromSalutation();
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(
                    flex: 5,
                    child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                            labelText: 'Full Name',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _ageController,
                        decoration: InputDecoration(
                            labelText: 'Age',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                            labelText: 'Gender',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        items: ['Male', 'Female', 'Other']
                            .map((g) =>
                                DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v!))),
              ]),
            ])));
  }

  Widget _buildContactSection() {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Contact Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixText: '+91 '),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) => (v!.length != 10) ? 'Invalid' : null),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                      labelText: 'Address',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    flex: 3,
                    child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                            labelText: 'Email',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        keyboardType: TextInputType.emailAddress)),
                const SizedBox(width: 12),
                Expanded(
                    flex: 2,
                    child: TextFormField(
                        controller: _pincodeController,
                        decoration: InputDecoration(
                            labelText: 'Pincode',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        validator: (v) => v!.length != 6 ? 'Invalid' : null)),
              ]),
            ])));
  }

  Widget _buildDoctorSection() {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Additional Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _doctorController,
                  decoration: InputDecoration(
                      labelText: 'Referring Doctor',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixText: 'Dr. ')),
              const SizedBox(height: 16),
              SwitchListTile(
                  title: const Text('B2B?', style: TextStyle(fontSize: 14)),
                  value: _b2b,
                  onChanged: (v) {
                    setState(() {
                      _b2b = v;
                      if (!v) {
                        _selectedB2BClientId = 0;
                        _selectedB2BClientName = '';
                      } else {
                        _showB2BClientDialog();
                      }
                    });
                  }),
              if (_selectedB2BClientName.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Selected B2B Client',
                            border: OutlineInputBorder()),
                        readOnly: true,
                        controller: TextEditingController(
                            text: _selectedB2BClientName))),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _freeTextController,
                  decoration: InputDecoration(
                      labelText: 'Remarks / Notes',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                  maxLines: 3),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: CheckboxListTile(
                        title:
                            const Text('VIP', style: TextStyle(fontSize: 14)),
                        value: _vip,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _vip = v!))),
                Expanded(
                    child: CheckboxListTile(
                        title: const Text('Urgent',
                            style: TextStyle(fontSize: 14)),
                        value: _urgent,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setState(() => _urgent = v!))),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                  value: _creditSelect,
                  decoration: InputDecoration(
                      labelText: 'Payment Type',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                  items: ['None', 'Credit', 'Trial']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _creditSelect = v!;
                      _credit = v == 'None' ? 0 : (v == 'Credit' ? 1 : 2);
                    });
                  }),
              if (isEditMode) ...[
                const Divider(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: _isCancelled ? Colors.red.shade50 : null,
                    border: _isCancelled
                        ? Border.all(color: Colors.red.shade200)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Cancel Work Order?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        value: _isCancelled,
                        onChanged: (v) => setState(() => _isCancelled = v),
                      ),
                      if (_isCancelled)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextFormField(
                            controller: _cancelReasonController,
                            decoration: const InputDecoration(
                              labelText: 'Cancellation Reason',
                              border: OutlineInputBorder(),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            maxLines: 2,
                            validator: (v) =>
                                _isCancelled && (v == null || v.isEmpty)
                                    ? 'Reason is required'
                                    : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ])));
  }

  Widget _buildActionButtons() {
    String btnText = isEditMode
        ? 'Update Work Order'
        : (isCopyMode ? 'Create Copy' : 'Create Work Order');
    return Column(children: [
      SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
              onPressed: _validateAndSave,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Text(btnText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)))),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)))),
    ]);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _collectionTime = picked);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (image != null) {
      setState(() {
        _prescriptionImage = image;
        _prescriptionPath =
            'homecollection/prescriptions/${DateTime.now().toIso8601String()}/${image.name}';
      });
    }
  }

  void _updateGenderFromSalutation() {
    if (_salutation == 'Ms' || _salutation == 'Mrs') {
      _gender = 'Female';
    } else if (_salutation == 'Mr') {
      _gender = 'Male';
    }
  }

  void _validateAndSave() {
    setState(() => _hasAttemptedValidation = true);

    if (_formKey.currentState!.validate() && _collectionTime != null) {
      _save();
    } else if (_collectionTime == null) {
      _showSnackBar('Please select collection time');
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    try {
      final storage = ref.read(storageServiceProvider);
      final managerName = storage.getFromSession('logged_in_emp_name');

      DateTime calendar;
      try {
        calendar = DateFormat('EEEE d MMM yyyy').parse(_collectionDate);
      } catch (e) {
        calendar = DateFormat('EEEE d MMMM yyyy').parse(_collectionDate);
      }

      final visitTime =
          '${_collectionTime!.hour.toString().padLeft(2, '0')}:${_collectionTime!.minute.toString().padLeft(2, '0')}';
      final patientName =
          '$_salutation. ${_toTitleCase(_nameController.text.trim())}';
      final mobile = _mobileController.text.trim();
      final address = _toTitleCase(_addressController.text.trim());
      final pincode = _pincodeController.text.trim();
      final doctorName = _toTitleCase(_doctorController.text.trim());
      final freeText = _freeTextController.text.trim();

      if (isEditMode) {
        final status =
            _isCancelled ? 'cancelled' : widget.existingWorkOrder!.status;
        final serverStatus =
            _isCancelled ? 'cancelled' : widget.existingWorkOrder!.serverStatus;

        final updatedOrder = widget.existingWorkOrder!.copyWith(
          patientName: patientName,
          visitDate: calendar,
          visitTime: visitTime,
          doctorName: doctorName,
          mobile: mobile,
          age: _ageController.text,
          gender: _gender,
          address: address,
          email: _emailController.text.toLowerCase(),
          pincode: pincode,
          freeText: freeText,
          vip: _vip,
          urgent: _urgent,
          credit: _credit,
          b2bClientId: _selectedB2BClientId,
          b2bClientName: _selectedB2BClientName,
          status: status,
          serverStatus: serverStatus,
          settings: {
            'send_sms': _msgSms ? 1 : 0,
            'send_whatsapp': _msgWhatsapp ? 1 : 0,
            'send_email': _msgEmail ? 1 : 0
          },
          lastUpdatedBy: managerName,
          lastUpdatedAt: DateTime.now(),
        );

        final now = DateTime.now();
        final log =
            "${DateFormat('MMMM dd, hh:mm a').format(now)} | $managerName | Work Order Updated";
        final timeline = List<dynamic>.from(widget.existingWorkOrder!.timeLine)
          ..add(log);

        if (_isCancelled && widget.existingWorkOrder!.status != 'cancelled') {
          final cancelLog =
              "${DateFormat('MMMM dd, hh:mm a').format(now)} | $managerName | Work Order Cancelled";
          timeline.add(cancelLog);
        }

        final customDoc = updatedOrder.buildDoc();
        customDoc['time_line'] = timeline;

        if (_isCancelled) {
          customDoc['cancel_reason'] = _cancelReasonController.text.trim();
        }

        final success = await ref
            .read(workOrderProvider)
            .updateWorkOrder(updatedOrder, customDoc: customDoc);
        _handleSaveResult(success, 'Work Order Updated');
      } else {
        final workOrder = WorkOrder.fromFormData(
          patientName: patientName,
          mobile: mobile,
          address: address,
          visitDate: calendar,
          visitTime: visitTime,
          managerId:
              int.parse(storage.getFromSession('logged_in_emp_id') ?? '0'),
          managerName: managerName,
          tenantId:
              int.parse(storage.getFromSession('logged_in_tenant_id') ?? '0'),
          salutation: _salutation,
          age: _ageController.text,
          gender: _gender,
          email: _emailController.text.toLowerCase(),
          pincode: pincode,
          doctorName: doctorName,
          freeText: freeText,
          prescriptionPath: _prescriptionPath,
          b2bClientId: _selectedB2BClientId,
          b2bClientName: _selectedB2BClientName,
          vip: _vip,
          urgent: _urgent,
          credit: _credit,
          sendSms: _msgSms,
          sendWhatsapp: _msgWhatsapp,
          sendEmail: _msgEmail,
        );

        if (isCopyMode) {
          final now = DateTime.now();
          final log = "${Util.gettime()} - $managerName - Work Order Copied";
          final docMap = jsonDecode(workOrder.doc);
          docMap['time_line'] = [log];
          final finalOrder = workOrder.copyWith(doc: jsonEncode(docMap));

          final success =
              await ref.read(workOrderProvider).createWorkOrder(finalOrder);
          _handleSaveResult(success, 'Work Order Copied Successfully');
        } else {
          final success =
              await ref.read(workOrderProvider).createWorkOrder(workOrder);
          _handleSaveResult(success, 'Work Order Created');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  void _handleSaveResult(bool success, String message) {
    setState(() => _isLoading = false);
    if (success && mounted) {
      _showSnackBar(message);
      Navigator.of(context).pop('refresh');
    } else if (!success && mounted) {
      _showSnackBar('Operation failed');
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('SMS Notifications'),
                  value: _msgSms,
                  onChanged: (v) => setDialogState(() => _msgSms = v),
                ),
                SwitchListTile(
                  title: const Text('WhatsApp Notifications'),
                  value: _msgWhatsapp,
                  onChanged: (v) => setDialogState(() => _msgWhatsapp = v),
                ),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  value: _msgEmail,
                  onChanged: (v) => setDialogState(() => _msgEmail = v),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _showB2BClientDialog() async {
    setState(() => _isLoading = true);

    try {
      final dbService = ref.read(postgresServiceProvider);
      final clients = await dbService.getB2BClients();

      if (clients != null && clients != "Error") {
        ref.read(_b2bClientsPod.notifier).state =
            List<Map<String, dynamic>>.from(clients);

        setState(() => _isLoading = false);

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => const _B2BClientDialog(),
        ).then((selectedClient) {
          if (selectedClient != null) {
            setState(() {
              _selectedB2BClientId = selectedClient['id'];
              _selectedB2BClientName =
                  '${selectedClient['first_name']} ${selectedClient['last_name']} (${selectedClient['client_master']['client_name']})';
            });
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _b2b = false;
        });
        _showSnackBar('Failed to load B2B clients');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _b2b = false;
      });
      _showSnackBar('Error loading B2B clients');
      debugPrint('Error: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    _cancelReasonController.dispose();
    super.dispose();
  }
}

class _B2BClientDialog extends ConsumerStatefulWidget {
  const _B2BClientDialog();

  @override
  ConsumerState<_B2BClientDialog> createState() => _B2BClientDialogState();
}

class _B2BClientDialogState extends ConsumerState<_B2BClientDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(_b2bClientsPod);
    final filtered = _searchQuery.isEmpty
        ? clients
        : clients
            .where((c) =>
                c['first_name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                c['client_master']['client_name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

    return Dialog(
      child: Container(
        height: 500,
        width: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Select B2B Client',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Client',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final client = filtered[i];
                  return ListTile(
                    title: Text(
                        '${client['first_name']} ${client['last_name']} (${client['client_master']['client_name']})'),
                    subtitle: Text(client['mobile'] ?? ''),
                    onTap: () => Navigator.pop(context, client),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

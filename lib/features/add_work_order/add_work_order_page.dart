import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../features/theme/theme.dart';

import '../../../../models/work_order.dart';
import 'controllers/add_work_order_controller.dart';
import 'providers.dart';

import 'widgets/patient_details_section.dart';
import 'widgets/contact_info_section.dart';
import 'widgets/image_upload_section.dart';
import 'widgets/cancellation_section.dart';
import 'widgets/work_order_section_card.dart';
import 'widgets/work_order_form_styles.dart';
import 'dialogs/pincode_search_dialog.dart';
import 'dialogs/b2b_client_dialog.dart';
import 'dialogs/settings_dialog.dart';

import '../../../../services/postgresService.dart';
import '../../../../config/settings.dart';
import '../../../../providers/storage_provider.dart';

class AddWorkOrderPage extends ConsumerStatefulWidget {
  final WorkOrder? existingWorkOrder;
  final WorkOrder? copyFrom;

  const AddWorkOrderPage({
    super.key,
    this.existingWorkOrder,
    this.copyFrom,
  });

  @override
  ConsumerState<AddWorkOrderPage> createState() => _AddWorkOrderPageState();
}

class _AddWorkOrderPageState extends ConsumerState<AddWorkOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _doctorController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;
  late TextEditingController _freeTextController;
  late TextEditingController _cancellationReasonController;
  late TextEditingController _marketingPersonNameController;
  late TextEditingController _marketingPersonNumberController;
  late TextEditingController _alternateMobileController;
  late TextEditingController _clientCodeController;
  late TextEditingController _doctorCodeController;

  String _salutation = 'Mr';
  String _gender = 'Male';
  String _collectionDate = '';
  TimeOfDay? _collectionTime;
  List<XFile> _prescriptionImages = [];
  List<String> _prescriptionPaths = [];

  bool _isVip = false;
  bool _isUrgent = false;
  bool _isCghs = false;

  int _credit = 0;
  String _creditSelect = 'None';

  bool _isB2B = false;
  int? _selectedB2BClientId;
  String? _selectedB2BClientName;

  bool _sendSms = true;
  bool _sendWhatsapp = true;
  bool _sendEmail = true;

  bool _isCancelled = false;
  bool _isAdmin = false;

  bool _isInitialized = false;
  bool _hasAttemptedValidation = false;

  final _imagePicker = ImagePicker();

  List<String> _suitableDates = [];

  bool get isEditMode => widget.existingWorkOrder != null;
  bool get isCopyMode => widget.copyFrom != null;

  @override
  void initState() {
    super.initState();
    _initializeControllers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      _isAdmin = storage.getFromSession('role_name') == 'ADMIN';

      if (isEditMode) {
        _loadData(widget.existingWorkOrder!, isCopy: false);
      } else if (isCopyMode) {
        _loadData(widget.copyFrom!, isCopy: true);
      } else {
        _initializeDates();
      }
      _loadB2BClients();
    });
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _ageController = TextEditingController(text: 'NA');
    _mobileController = TextEditingController();
    _emailController = TextEditingController(text: 'NA');
    _doctorController = TextEditingController();
    _addressController = TextEditingController(text: 'NA');
    _pincodeController = TextEditingController();
    _freeTextController = TextEditingController();
    _cancellationReasonController = TextEditingController();
    _marketingPersonNameController = TextEditingController();
    _marketingPersonNumberController = TextEditingController();
    _alternateMobileController = TextEditingController();
    _clientCodeController = TextEditingController();
    _doctorCodeController = TextEditingController();
  }

  void _initializeDates() {
    if (!mounted) return;
    setState(() {
      // final today =
      //     Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
      final today = DateTime.now();
      for (int i = 0; i <= 9; i++) {
        final date = today.add(Duration(days: i));
        _suitableDates.add(DateFormat('EEEE d MMM yyyy').format(date));
      }
      _collectionDate = _suitableDates.isNotEmpty ? _suitableDates[0] : '';
      _isInitialized = true;
    });
  }

  void _initializeDatesForEdit(DateTime existingDate) {
    if (!mounted) return;
    setState(() {
      // final today =
      //     Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
      final today = DateTime.now();
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

  Future<void> _loadB2BClients() async {
    try {
      final dbService = ref.read(postgresServiceProvider);
      final clients = await dbService.getB2BClients();

      if (clients != null && clients != "Error" && mounted) {
        ref.read(b2bClientsProvider.notifier).state =
            List<Map<String, dynamic>>.from(clients);
      }
    } catch (e) {
      debugPrint("Error loading B2B clients: $e");
    }
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
    _marketingPersonNameController.text = wo.marketingPersonName;
    _marketingPersonNumberController.text = wo.marketingPersonNumber;
    _alternateMobileController.text = wo.alternateMobile;
    _clientCodeController.text = wo.clientCode;
    _doctorCodeController.text = wo.doctorCode;

    _gender = wo.gender.isNotEmpty ? wo.gender : 'Male';
    _isVip = wo.vip;
    _isUrgent = wo.urgent;
    _isCghs = wo.cghsClient;
    _credit = wo.credit;
    _creditSelect = _credit == 1 ? 'Credit' : (_credit == 2 ? 'Trial' : 'None');

    _selectedB2BClientId = wo.b2bClientId;
    _selectedB2BClientName = wo.b2bClientName;
    _isB2B = wo.b2bClientId != null && wo.b2bClientId! > 0;

    if (!isCopy) {
      _isCancelled = wo.status == 'cancelled';
      _cancellationReasonController.text = wo.parsedDoc['cancel_reason'] ?? '';
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
      if (wo.prescriptionPhoto.isNotEmpty) {
        _prescriptionPaths = wo.prescriptionPhoto
            .split(',')
            .where((p) => p.trim().isNotEmpty)
            .toList();
      }
    }

    if (wo.settings != null) {
      _sendSms = wo.settings!['send_sms'] == 1;
      _sendWhatsapp = wo.settings!['send_whatsapp'] == 1;
      _sendEmail = wo.settings!['send_email'] == 1;
    }

    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _doctorController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _freeTextController.dispose();
    _cancellationReasonController.dispose();
    _marketingPersonNameController.dispose();
    _marketingPersonNumberController.dispose();
    _alternateMobileController.dispose();
    _clientCodeController.dispose();
    _doctorCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _updateGenderFromSalutation(String salutation) {
    setState(() {
      _salutation = salutation;
      if (salutation == 'Ms' || salutation == 'Mrs') {
        _gender = 'Female';
      } else if (salutation == 'Mr') {
        _gender = 'Male';
      }
    });
  }

  void _validateAndSave() {
    setState(() => _hasAttemptedValidation = true);

    if (_formKey.currentState!.validate() && _collectionTime != null) {
      // Validate future time for same-day appointments
      if (!_validateFutureTime()) {
        _showSnackBar('Collection time must be in the future');
        return;
      }
      _save();
    } else if (_collectionTime == null) {
      _showSnackBar('Please select collection time');
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  bool _validateFutureTime() {
    if (_collectionTime == null || _collectionDate.isEmpty) return true;

    try {
      DateTime collectionDateTime;
      try {
        collectionDateTime =
            DateFormat('EEEE d MMM yyyy').parse(_collectionDate);
      } catch (_) {
        collectionDateTime =
            DateFormat('EEEE d MMMM yyyy').parse(_collectionDate);
      }

      final fullDateTime = DateTime(
        collectionDateTime.year,
        collectionDateTime.month,
        collectionDateTime.day,
        _collectionTime!.hour,
        _collectionTime!.minute,
      );

      final now = DateTime.now();
      return fullDateTime.isAfter(now);
    } catch (e) {
      debugPrint('Error validating future time: $e');
      return true;
    }
  }

  Future<void> _save() async {
    // Generate S3-style paths with timestamp prefix for each new image
    // (matches HC Process pattern for unique filenames)
    List<String> prescriptionPaths = List.from(_prescriptionPaths);
    List<XFile> newImages = [];
    if (_prescriptionImages.isNotEmpty) {
      final todayFolder = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (final image in _prescriptionImages) {
        final timestampedName =
            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final path =
            'homecollection/prescriptions/$todayFolder/$timestampedName';
        prescriptionPaths.add(path);
        newImages.add(image);
      }
    }

    final result =
        await ref.read(addWorkOrderControllerProvider.notifier).saveWorkOrder(
              isEditMode: isEditMode,
              isCopyMode: isCopyMode,
              existingWorkOrder: widget.existingWorkOrder,
              collectionDate: _collectionDate,
              collectionTime: _collectionTime,
              salutation: _salutation,
              name: _toTitleCase(_nameController.text.trim()),
              mobile: _mobileController.text.trim(),
              address: _toTitleCase(_addressController.text.trim()),
              pincode: _pincodeController.text.trim(),
              doctor: _toTitleCase(_doctorController.text.trim()),
              age: _ageController.text.trim(),
              gender: _gender,
              email: _emailController.text.trim().toLowerCase(),
              freeText: _freeTextController.text.trim(),
              isVip: _isVip,
              isUrgent: _isUrgent,
              isCghs: _isCghs,
              credit: _credit,
              b2bClientId: _selectedB2BClientId,
              b2bClientName: _selectedB2BClientName,
              marketingPersonName:
                  _toTitleCase(_marketingPersonNameController.text.trim()),
              marketingPersonNumber:
                  _marketingPersonNumberController.text.trim(),
              alternateMobile: _alternateMobileController.text.trim(),
              clientCode: _clientCodeController.text.trim(),
              doctorCode: _doctorCodeController.text.trim(),
              sendSms: _sendSms,
              sendWhatsapp: _sendWhatsapp,
              sendEmail: _sendEmail,
              prescriptionPaths: prescriptionPaths,
              prescriptionImages: newImages,
              isCancelled: _isCancelled,
              cancelReason: _cancellationReasonController.text.trim(),
            );

    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.pop(context, _isCancelled ? 'cancelled' : 'refresh');
      Future.microtask(() {
        if (mounted) _showSnackBar(result['message']);
      });
    } else {
      if (mounted) _showSnackBar(result['message'] ?? 'Operation Failed');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
      ),
    );
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _collectionTime = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked =
          await _imagePicker.pickImage(source: source, imageQuality: 50);
      if (picked != null) {
        setState(() {
          _prescriptionImages.add(picked);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showPincodeDialog() {
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => PincodeSearchDialog(
        searchController: searchCtrl,
        onSelected: (pincode, address) {
          setState(() {
            _pincodeController.text = pincode;
            _addressController.text = address;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showB2BDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const B2BClientDialog(),
    );

    if (result != null && result is Map) {
      setState(() {
        _selectedB2BClientId = result['id'];

        final clientMaster = result['client_master'];
        final clientName =
            clientMaster != null ? clientMaster['client_name'] ?? '' : '';
        _selectedB2BClientName =
            '${result['first_name']} ${result['last_name']}${clientName.isNotEmpty ? ' ($clientName)' : ''}';
        _isB2B = true;

        _sendSms = false;
        _sendWhatsapp = false;
        _sendEmail = false;
      });
    } else {
      if (_selectedB2BClientId == null) {
        setState(() {
          _isB2B = false;
          _sendSms = true;
          _sendWhatsapp = true;
          _sendEmail = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    String title = 'New Work Order';
    if (isEditMode) title = 'Edit Work Order';
    if (isCopyMode) title = 'Copy Work Order';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(title),
      body: _isInitialized
          ? Stack(
              children: [
                Form(
                  key: _formKey,
                  child: isWideScreen
                      ? _buildDesktopLayout()
                      : _buildMobileLayout(),
                ),
                if (ref.watch(addWorkOrderControllerProvider))
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            )
          : Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              if (isCopyMode) _buildCopyBanner(),
              SizedBox(height: AppSpacing.lg),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: WorkOrderSectionCard(
                        title: 'Schedule',
                        icon: Icons.calendar_today_rounded,
                        color: AppColors.secondary,
                        child: Column(
                          children: [
                            _buildDateTimeFields(),
                            SizedBox(height: AppSpacing.lg),
                            ImageUploadSection(
                              images: _prescriptionImages,
                              initialUrls: _prescriptionPaths,
                              onPickImage: _pickImage,
                              onRemoveImage: (i) => setState(
                                  () => _prescriptionImages.removeAt(i)),
                              onRemoveExisting: (i) => setState(
                                  () => _prescriptionPaths.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: WorkOrderSectionCard(
                        title: 'Patient Details',
                        icon: Icons.person_rounded,
                        color: AppColors.primary,
                        child: PatientDetailsSection(
                          salutation: _salutation,
                          nameController: _nameController,
                          ageController: _ageController,
                          mobileController: _mobileController,
                          alternateMobileController: _alternateMobileController,
                          emailController: _emailController,
                          gender: _gender,
                          onSalutationChanged: (v) =>
                              _updateGenderFromSalutation(v!),
                          onGenderChanged: (v) => setState(() => _gender = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: WorkOrderSectionCard(
                        title: 'Additional Details',
                        icon: Icons.medical_services_rounded,
                        color: AppColors.secondary,
                        child: _buildAdditionalFields(),
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: WorkOrderSectionCard(
                        title: 'Contact Information',
                        icon: Icons.contact_phone_rounded,
                        color: AppColors.primary,
                        child: _buildContactFieldsDesktop(),
                      ),
                    ),
                  ],
                ),
              ),
              if (isEditMode && _isAdmin) ...[
                SizedBox(height: AppSpacing.lg),
                WorkOrderSectionCard(
                  title: 'Cancellation',
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  child: CancellationSection(
                    isCancelled: _isCancelled,
                    reasonController: _cancellationReasonController,
                    onToggle: (v) => setState(() => _isCancelled = v),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.xl),
              _buildActionButtons(),
              SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          if (isCopyMode) _buildCopyBanner(),
          SizedBox(height: AppSpacing.md),
          WorkOrderSectionCard(
            title: 'Schedule',
            icon: Icons.calendar_today_rounded,
            color: AppColors.secondary,
            child: Column(
              children: [
                _buildDateTimeFields(),
                SizedBox(height: AppSpacing.lg),
                ImageUploadSection(
                  images: _prescriptionImages,
                  initialUrls: _prescriptionPaths,
                  onPickImage: _pickImage,
                  onRemoveImage: (i) =>
                      setState(() => _prescriptionImages.removeAt(i)),
                  onRemoveExisting: (i) =>
                      setState(() => _prescriptionPaths.removeAt(i)),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          WorkOrderSectionCard(
            title: 'Patient Details',
            icon: Icons.person_rounded,
            color: AppColors.primary,
            child: PatientDetailsSection(
              salutation: _salutation,
              nameController: _nameController,
              ageController: _ageController,
              mobileController: _mobileController,
              alternateMobileController: _alternateMobileController,
              emailController: _emailController,
              gender: _gender,
              onSalutationChanged: (v) => _updateGenderFromSalutation(v!),
              onGenderChanged: (v) => setState(() => _gender = v!),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          WorkOrderSectionCard(
            title: 'Contact Information',
            icon: Icons.contact_phone_rounded,
            color: AppColors.primary,
            child: ContactInfoSection(
              addressController: _addressController,
              pincodeController: _pincodeController,
              freeTextController: _freeTextController,
              onPincodeTap: _showPincodeDialog,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          WorkOrderSectionCard(
            title: 'Additional Details',
            icon: Icons.medical_services_rounded,
            color: AppColors.secondary,
            child: _buildAdditionalFields(),
          ),
          if (isEditMode && _isAdmin) ...[
            SizedBox(height: AppSpacing.md),
            WorkOrderSectionCard(
              title: 'Cancellation',
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              child: CancellationSection(
                isCancelled: _isCancelled,
                reasonController: _cancellationReasonController,
                onToggle: (v) => setState(() => _isCancelled = v),
              ),
            ),
          ],
          SizedBox(height: AppSpacing.xl),
          _buildActionButtons(),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildDateTimeFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _collectionDate.isNotEmpty ? _collectionDate : null,
          decoration: WorkOrderFormStyles.inputDecoration('Collection Date',
              icon: Icons.event),
          items: _suitableDates
              .map((date) => DropdownMenuItem(value: date, child: Text(date)))
              .toList(),
          onChanged: (value) => setState(() => _collectionDate = value!),
        ),
        SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: _selectTime,
          borderRadius: AppRadius.smAll,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(
                color: _hasAttemptedValidation && _collectionTime == null
                    ? AppColors.error
                    : AppColors.divider,
                width:
                    _hasAttemptedValidation && _collectionTime == null ? 2 : 1,
              ),
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    color: _collectionTime == null
                        ? AppColors.textHint
                        : AppColors.primary,
                    size: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _collectionTime?.format(context) ?? 'Select Time',
                    style: TextStyle(
                      fontSize: 16,
                      color: _collectionTime == null
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_collectionTime != null)
                  IconButton(
                    icon:
                        Icon(Icons.clear, size: 18, color: AppColors.textHint),
                    onPressed: () => setState(() => _collectionTime = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
        if (_hasAttemptedValidation && _collectionTime == null)
          Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Please select collection time',
                  style: TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          ),
      ],
    );
  }

  Widget _buildAdditionalFields() {
    return Column(
      children: [
        TextFormField(
          controller: _doctorController,
          decoration: WorkOrderFormStyles.inputDecoration('Referring Doctor',
              icon: Icons.medical_services_outlined, prefix: 'Dr. '),
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _marketingPersonNameController,
                decoration: WorkOrderFormStyles.inputDecoration(
                    'Marketing Person Name',
                    icon: Icons.person_outline),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                controller: _marketingPersonNumberController,
                decoration: WorkOrderFormStyles.inputDecoration(
                    'Marketing Person Number',
                    icon: Icons.phone_outlined),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _clientCodeController,
                decoration: WorkOrderFormStyles.inputDecoration('Client Code',
                    icon: Icons.badge_outlined),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                controller: _doctorCodeController,
                decoration: WorkOrderFormStyles.inputDecoration('Doctor Code',
                    icon: Icons.local_hospital_outlined),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        _buildB2BToggle(),
        if (_selectedB2BClientName != null &&
            _selectedB2BClientName!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: AppRadius.smAll,
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.business, color: AppColors.primary, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(_selectedB2BClientName!,
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: AppSpacing.md),
        // TextFormField(
        //   controller: _freeTextController,
        //   decoration: WorkOrderFormStyles.inputDecoration('Remarks / Notes',
        //       icon: Icons.notes),
        //   maxLines: 3,
        // ),
        SizedBox(height: AppSpacing.md),
        _buildTagsRow(),
        SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          value: _creditSelect,
          decoration: WorkOrderFormStyles.inputDecoration('Payment Type',
              icon: Icons.payment),
          items: ['None', 'Credit', 'Trial']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _creditSelect = v!;
              _credit = v == 'None' ? 0 : (v == 'Credit' ? 1 : 2);
            });
          },
        ),
      ],
    );
  }

  Widget _buildB2BToggle() {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color:
            _isB2B ? AppColors.primary.withOpacity(0.05) : AppColors.surfaceAlt,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color:
              _isB2B ? AppColors.primary.withOpacity(0.2) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.business_center,
              color: _isB2B ? AppColors.primary : AppColors.textHint, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('B2B Client',
                style: TextStyle(
                    color:
                        _isB2B ? AppColors.primary : AppColors.textSecondary)),
          ),
          Switch(
            value: _isB2B,
            activeColor: AppColors.primary,
            onChanged: (v) {
              setState(() {
                _isB2B = v;
                if (!v) {
                  _selectedB2BClientId = null;
                  _selectedB2BClientName = '';
                  _sendSms = true;
                  _sendWhatsapp = true;
                  _sendEmail = true;
                } else {
                  _showB2BDialog();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagsRow() {
    return Row(
      children: [
        Expanded(
            child: _buildTagChip(
                'VIP', _isVip, (v) => setState(() => _isVip = v))),
        SizedBox(width: AppSpacing.md),
        Expanded(
            child: _buildTagChip(
                'Urgent', _isUrgent, (v) => setState(() => _isUrgent = v))),
        SizedBox(width: AppSpacing.md),
        Expanded(
            child: _buildTagChip(
                'CGHS', _isCghs, (v) => setState(() => _isCghs = v))),
      ],
    );
  }

  Widget _buildTagChip(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: AppRadius.smAll,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: value
              ? (label == 'Urgent'
                  ? AppColors.error.withOpacity(0.1)
                  : label == 'VIP'
                      ? AppColors.warning.withOpacity(0.1)
                      : AppColors.secondary.withOpacity(0.1))
              : AppColors.surfaceAlt,
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: value
                ? (label == 'Urgent'
                    ? AppColors.error
                    : label == 'VIP'
                        ? AppColors.warning
                        : AppColors.secondary)
                : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: value
                  ? (label == 'Urgent'
                      ? AppColors.error
                      : label == 'VIP'
                          ? AppColors.warning
                          : AppColors.secondary)
                  : AppColors.textHint,
            ),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value
                      ? (label == 'Urgent'
                          ? AppColors.error
                          : label == 'VIP'
                              ? AppColors.warning
                              : AppColors.secondary)
                      : AppColors.textSecondary,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactFieldsDesktop() {
    return Column(
      children: [
        TextFormField(
          controller: _addressController,
          decoration: WorkOrderFormStyles.inputDecoration('Address',
              icon: Icons.location_on_outlined),
          maxLines: 3,
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _emailController,
                decoration: WorkOrderFormStyles.inputDecoration('Email',
                    icon: Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeController,
                      decoration:
                          WorkOrderFormStyles.inputDecoration('Pincode'),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      validator: (v) => v!.length != 6 ? 'Invalid' : null,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.search, color: AppColors.primary),
                      tooltip: 'Search Pincode',
                      onPressed: _showPincodeDialog,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _freeTextController,
          decoration: WorkOrderFormStyles.inputDecoration('Remarks / Notes',
              icon: Icons.notes),
          maxLines: 2,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: AppColors.surface,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: AppPadding.badge,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              borderRadius: AppRadius.lgAll,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title,
              style: AppTextStyles.badge.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
      actions: [
        _buildNotificationChip(),
        SizedBox(width: AppSpacing.sm),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.primary.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationChip() {
    final activeCount =
        [_sendSms, _sendWhatsapp, _sendEmail].where((b) => b).length;
    return ActionChip(
      avatar: Icon(Icons.notifications_outlined,
          size: 18,
          color: activeCount > 0 ? AppColors.primary : AppColors.textHint),
      label: Text('$activeCount/3'),
      backgroundColor: activeCount > 0
          ? AppColors.primary.withOpacity(0.1)
          : AppColors.surfaceAlt,
      labelStyle: TextStyle(
        color: activeCount > 0 ? AppColors.primary : AppColors.textHint,
        fontWeight: FontWeight.w500,
      ),
      onPressed: () async {
        final result = await showDialog(
          context: context,
          builder: (context) => SettingsDialog(
            initialSms: _sendSms,
            initialWhatsapp: _sendWhatsapp,
            initialEmail: _sendEmail,
          ),
        );
        if (result != null && result is Map) {
          setState(() {
            _sendSms = result['sms'];
            _sendWhatsapp = result['whatsapp'];
            _sendEmail = result['email'];
          });
        }
      },
    );
  }

  Widget _buildCopyBanner() {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(Icons.copy_rounded, color: AppColors.primary),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Creating a Copy',
                    style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                Text('Please select a new date and time.',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isLoading = ref.watch(addWorkOrderControllerProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    String btnText = isEditMode
        ? 'Update Work Order'
        : (isCopyMode ? 'Create Copy' : 'Create Work Order');

    return isWide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.textHint),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textSecondary)),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              SizedBox(
                width: 280,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(btnText,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        : Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(btnText,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.textHint),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textSecondary)),
                ),
              ),
            ],
          );
  }
}

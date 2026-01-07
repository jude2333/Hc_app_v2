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
import '../../features/core/util.dart';
import '../../../config/settings.dart';
import '../../features/theme/theme.dart';
import '../../providers/pincode_provider.dart';

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

    final isWideScreen = MediaQuery.of(context).size.width > 800;

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
                if (_isLoading) _buildLoadingOverlay(),
              ],
            )
          : Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
        [_msgSms, _msgWhatsapp, _msgEmail].where((b) => b).length;
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
      onPressed: _showSettingsDialog,
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: AppSpacing.md),
                Text('Processing...', style: AppTextStyles.body),
              ],
            ),
          ),
        ),
      ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          icon: Icons.calendar_today_rounded,
                          title: 'Schedule',
                          color: AppColors.secondary,
                          child: _buildDateTimeFields(),
                        ),
                        SizedBox(height: AppSpacing.lg),
                        _buildSectionCard(
                          icon: Icons.person_rounded,
                          title: 'Patient Details',
                          color: AppColors.primary,
                          child: _buildPatientFields(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          icon: Icons.contact_phone_rounded,
                          title: 'Contact Information',
                          color: AppColors.success,
                          child: _buildContactFields(),
                        ),
                        SizedBox(height: AppSpacing.lg),
                        _buildSectionCard(
                          icon: Icons.medical_services_rounded,
                          title: 'Additional Details',
                          color: AppColors.secondary,
                          child: _buildAdditionalFields(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        if (isCopyMode) _buildCopyBanner(),
        SizedBox(height: AppSpacing.md),
        _buildSectionCard(
          icon: Icons.calendar_today_rounded,
          title: 'Schedule',
          color: AppColors.secondary,
          child: _buildDateTimeFields(),
        ),
        SizedBox(height: AppSpacing.md),
        _buildSectionCard(
          icon: Icons.person_rounded,
          title: 'Patient Details',
          color: AppColors.primary,
          child: _buildPatientFields(),
        ),
        SizedBox(height: AppSpacing.md),
        _buildSectionCard(
          icon: Icons.contact_phone_rounded,
          title: 'Contact Information',
          color: AppColors.success,
          child: _buildContactFields(),
        ),
        SizedBox(height: AppSpacing.md),
        _buildSectionCard(
          icon: Icons.medical_services_rounded,
          title: 'Additional Details',
          color: AppColors.secondary,
          child: _buildAdditionalFields(),
        ),
        SizedBox(height: AppSpacing.xl),
        _buildActionButtons(),
        SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildCopyBanner() {
    return Container(
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

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: AppSpacing.md),
                Text(title, style: AppTextStyles.h3.copyWith(color: color)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label,
      {IconData? icon, String? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefix,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
    );
  }

  Widget _buildDateTimeFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _collectionDate.isNotEmpty ? _collectionDate : null,
          decoration: _inputDecoration('Collection Date', icon: Icons.event),
          items: _suitableDates
              .map((date) => DropdownMenuItem(value: date, child: Text(date)))
              .toList(),
          onChanged: (value) => setState(() => _collectionDate = value!),
        ),
        SizedBox(height: AppSpacing.md),
        InkWell(
          onTap: () => _selectTime(context),
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
        SizedBox(height: AppSpacing.lg),
        _buildImageUpload(),
      ],
    );
  }

  Widget _buildImageUpload() {
    if (_prescriptionImage == null && _prescriptionPath.isEmpty) {
      return OutlinedButton.icon(
        icon: Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
        label: Text('Upload Prescription',
            style: TextStyle(color: AppColors.secondary)),
        onPressed: _showImageSourceDialog,
        style: OutlinedButton.styleFrom(
          side:
              BorderSide(color: AppColors.secondary, style: BorderStyle.solid),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: AppRadius.smAll,
            ),
            child: _prescriptionImage != null
                ? (kIsWeb
                    ? Image.network(_prescriptionImage!.path, fit: BoxFit.cover)
                    : Image.file(File(_prescriptionImage!.path),
                        fit: BoxFit.cover))
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, color: AppColors.textHint, size: 32),
                        SizedBox(height: AppSpacing.xs),
                        Text('Prescription uploaded',
                            style: TextStyle(color: AppColors.textHint)),
                      ],
                    ),
                  ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          icon: Icon(Icons.refresh, size: 16),
          label: Text('Change'),
          onPressed: _showImageSourceDialog,
        ),
      ],
    );
  }

  Widget _buildPatientFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _salutation.isEmpty ? null : _salutation,
                decoration: _inputDecoration('Title'),
                items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _salutation = v!;
                    _updateGenderFromSalutation();
                  });
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 5,
              child: TextFormField(
                controller: _nameController,
                decoration:
                    _inputDecoration('Full Name', icon: Icons.person_outline),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ageController,
                decoration: _inputDecoration('Age', icon: Icons.cake_outlined),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: _inputDecoration('Gender'),
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactFields() {
    return Column(
      children: [
        TextFormField(
          controller: _mobileController,
          decoration: _inputDecoration('Mobile Number',
              icon: Icons.phone_outlined, prefix: '+91 '),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          validator: (v) => (v!.length != 10) ? 'Invalid' : null,
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _addressController,
          decoration:
              _inputDecoration('Address', icon: Icons.location_on_outlined),
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
                decoration:
                    _inputDecoration('Email', icon: Icons.email_outlined),
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
                      decoration: _inputDecoration('Pincode'),
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
                      onPressed: () => _showPincodeSearchDialog(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalFields() {
    return Column(
      children: [
        TextFormField(
          controller: _doctorController,
          decoration: _inputDecoration('Referring Doctor',
              icon: Icons.medical_services_outlined, prefix: 'Dr. '),
        ),
        SizedBox(height: AppSpacing.md),
        _buildB2BToggle(),
        if (_selectedB2BClientName.isNotEmpty)
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
                    child: Text(_selectedB2BClientName,
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _freeTextController,
          decoration: _inputDecoration('Remarks / Notes', icon: Icons.notes),
          maxLines: 3,
        ),
        SizedBox(height: AppSpacing.md),
        _buildTagsRow(),
        SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          value: _creditSelect,
          decoration: _inputDecoration('Payment Type', icon: Icons.payment),
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
        if (isEditMode) ...[
          SizedBox(height: AppSpacing.lg),
          _buildCancellationSection(),
        ],
      ],
    );
  }

  Widget _buildB2BToggle() {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color:
            _b2b ? AppColors.primary.withOpacity(0.05) : AppColors.surfaceAlt,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: _b2b ? AppColors.primary.withOpacity(0.2) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.business_center,
              color: _b2b ? AppColors.primary : AppColors.textHint, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('B2B Client',
                style: TextStyle(
                    color: _b2b ? AppColors.primary : AppColors.textSecondary)),
          ),
          Switch(
            value: _b2b,
            activeColor: AppColors.primary,
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
            child: _buildTagChip('VIP', _vip, (v) => setState(() => _vip = v))),
        SizedBox(width: AppSpacing.md),
        Expanded(
            child: _buildTagChip(
                'Urgent', _urgent, (v) => setState(() => _urgent = v))),
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
                  : AppColors.warning.withOpacity(0.1))
              : AppColors.surfaceAlt,
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: value
                ? (label == 'Urgent' ? AppColors.error : AppColors.warning)
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
                  ? (label == 'Urgent' ? AppColors.error : AppColors.warning)
                  : AppColors.textHint,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(label,
                style: TextStyle(
                  color: value
                      ? (label == 'Urgent'
                          ? AppColors.error
                          : AppColors.warning)
                      : AppColors.textSecondary,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationSection() {
    return Container(
      decoration: BoxDecoration(
        color: _isCancelled
            ? AppColors.error.withOpacity(0.05)
            : AppColors.surfaceAlt,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: _isCancelled
              ? AppColors.error.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isCancelled = !_isCancelled),
            borderRadius: AppRadius.smAll,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined,
                      color:
                          _isCancelled ? AppColors.error : AppColors.textHint),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Cancel Work Order',
                        style: TextStyle(
                          color: _isCancelled
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: _isCancelled
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ),
                  Switch(
                    value: _isCancelled,
                    activeColor: AppColors.error,
                    onChanged: (v) => setState(() => _isCancelled = v),
                  ),
                ],
              ),
            ),
          ),
          if (_isCancelled)
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: TextFormField(
                controller: _cancelReasonController,
                decoration: _inputDecoration('Cancellation Reason'),
                maxLines: 2,
                validator: (v) => _isCancelled && (v == null || v.isEmpty)
                    ? 'Reason is required'
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    String btnText = isEditMode
        ? 'Update Work Order'
        : (isCopyMode ? 'Create Copy' : 'Create Work Order');

    final isWide = MediaQuery.of(context).size.width > 600;

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
                  onPressed: _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Text(btnText,
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
                  onPressed: _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Text(btnText,
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: AppRadius.smAll,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(Icons.photo_library, color: AppColors.secondary),
              ),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: AppSpacing.md),
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          constraints: const BoxConstraints(maxWidth: 400),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: AppRadius.smAll,
                        ),
                        child: Icon(Icons.notifications_outlined,
                            color: AppColors.primary),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text('Notification Settings', style: AppTextStyles.h3),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textHint),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  _buildNotificationToggle(
                    'SMS',
                    Icons.sms_outlined,
                    _msgSms,
                    (v) => setDialogState(() => _msgSms = v),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _buildNotificationToggle(
                    'WhatsApp',
                    Icons.chat_outlined,
                    _msgWhatsapp,
                    (v) => setDialogState(() => _msgWhatsapp = v),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _buildNotificationToggle(
                    'Email',
                    Icons.email_outlined,
                    _msgEmail,
                    (v) => setDialogState(() => _msgEmail = v),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.smAll),
                      ),
                      child: Text('Save Settings'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
      String label, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color:
            value ? AppColors.success.withOpacity(0.05) : AppColors.surfaceAlt,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: value ? AppColors.success.withOpacity(0.3) : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppColors.success : AppColors.textHint, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color:
                        value ? AppColors.success : AppColors.textSecondary)),
          ),
          Switch(
            value: value,
            activeColor: AppColors.success,
            onChanged: onChanged,
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
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
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

      debugPrint('🔍 B2B clients response: $clients'); // ADD THIS
      debugPrint('🔍 B2B clients type: ${clients.runtimeType}'); // ADD THIS
      debugPrint(
          '🔍 B2B clients length: ${clients is List ? clients.length : "not a list"}');

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

  void _showPincodeSearchDialog() {
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => _PincodeSearchDialog(
        searchController: searchController,
        onSelected: (pincode, address) {
          setState(() {
            _pincodeController.text = pincode;
            _addressController.text = address;
          });
          Navigator.pop(dialogContext);
        },
      ),
    );
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
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Container(
        height: 500,
        width: 450,
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(Icons.business, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.md),
                Text('Select B2B Client', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, i) {
                  final client = filtered[i];
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        client['first_name'][0].toUpperCase(),
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    title: Text(
                        '${client['first_name']} ${client['last_name']}',
                        style: AppTextStyles.body),
                    subtitle: Text(client['client_master']['client_name'] ?? '',
                        style: AppTextStyles.caption),
                    trailing:
                        Icon(Icons.chevron_right, color: AppColors.textHint),
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

/// Pincode Search Dialog with initial data loading
class _PincodeSearchDialog extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final Function(String pincode, String address) onSelected;

  const _PincodeSearchDialog({
    required this.searchController,
    required this.onSelected,
  });

  @override
  ConsumerState<_PincodeSearchDialog> createState() =>
      _PincodeSearchDialogState();
}

class _PincodeSearchDialogState extends ConsumerState<_PincodeSearchDialog> {
  List<Map<String, dynamic>> pincodeResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final service = ref.read(pincodeServiceProvider);
      final results = await service.getInitialPincodes();
      if (mounted) {
        setState(() {
          pincodeResults = results;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial pincodes: $e');
      if (mounted) {
        setState(() {
          pincodeResults = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _doSearch(String query) async {
    setState(() => isLoading = true);
    try {
      final service = ref.read(pincodeServiceProvider);
      final results = await service.searchPincodes(query);
      if (mounted) {
        setState(() {
          pincodeResults = results;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Pincode search error: $e');
      if (mounted) {
        setState(() {
          pincodeResults = [];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Container(
        width: 500,
        height: 450,
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: AppPadding.badge,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text('Search Pincode',
                      style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textHint),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            TextField(
              controller: widget.searchController,
              decoration: InputDecoration(
                hintText: 'Enter pincode or area name...',
                prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                suffixIcon: IconButton(
                  icon: Icon(Icons.arrow_forward, color: AppColors.primary),
                  onPressed: () => _doSearch(widget.searchController.text),
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.smAll,
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _doSearch,
              autofocus: true,
            ),
            SizedBox(height: AppSpacing.md),
            Expanded(
              child: isLoading
                  ? Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : pincodeResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_searching,
                                  color: AppColors.textHint, size: 48),
                              SizedBox(height: AppSpacing.sm),
                              Text('No pincodes found',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: pincodeResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (context, index) {
                            final item = pincodeResults[index];
                            final pincode = item['pincode']?.toString() ?? '';
                            final area = item['area']?.toString() ?? '';
                            final district = item['district']?.toString() ?? '';
                            final city = item['city']?.toString() ?? '';

                            final isNoResult = pincode == 'No Pincode Found.';

                            return ListTile(
                              leading: Container(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: isNoResult
                                      ? AppColors.error.withOpacity(0.1)
                                      : AppColors.primary.withOpacity(0.1),
                                  borderRadius: AppRadius.smAll,
                                ),
                                child: Icon(
                                  isNoResult ? Icons.error : Icons.location_on,
                                  color: isNoResult
                                      ? AppColors.error
                                      : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(pincode,
                                  style: AppTextStyles.body
                                      .copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text('$area, $district, $city',
                                  style: AppTextStyles.caption),
                              onTap: isNoResult
                                  ? null
                                  : () {
                                      widget.onSelected(
                                          pincode, '$area, $district, $city');
                                    },
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

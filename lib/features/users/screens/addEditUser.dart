import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import 'package:anderson_crm_flutter/features/users/providers/users_providers.dart';
import '../../../config/settings.dart';
import '../../theme/theme.dart';

class AddEditUserPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? userData;
  final bool isEdit;

  const AddEditUserPage({
    Key? key,
    this.userData,
    this.isEdit = false,
  }) : super(key: key);

  @override
  ConsumerState<AddEditUserPage> createState() => _AddEditUserPageState();
}

class _AddEditUserPageState extends ConsumerState<AddEditUserPage> {
  final _formKey = GlobalKey<FormState>();
  Timer? _debounceTimer;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _roleSearchController = TextEditingController();

  bool _loading = false;
  bool _overlay = false;
  String _empId = '';
  String _roleId = '';
  String _roleName = '';
  List<String> _selectedRoleIds = [];
  List<Map<String, dynamic>> _selectedRoles = [];
  String _departmentId = '64';
  String _departmentName = 'HOME COLLECTION';
  String _centerId = '';
  String _centerName = '';
  List<Map<String, dynamic>> _allocatedAreas = [];
  PlatformFile? _selectedFile;
  String _uploadedFileName = '';
  bool _rolesModified = false;

  bool _showRoleSheet = false;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _emailController.dispose();
    _roleSearchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final storage = ref.read(storageServiceProvider);
    _centerId = storage.getFromSession("logged_in_tenant_id") ?? "";
    _centerName = storage.getFromSession("logged_in_tenant_name") ?? "";

    if (widget.isEdit && widget.userData != null) {
      final item = widget.userData!;
      _empId = item['emp_id']?.toString() ?? '';
      _firstNameController.text = item['first_name'] ?? '';
      _lastNameController.text = item['last_name'] ?? '';
      _mobileController.text = item['mobile'] ?? '';
      _addressController.text = item['address'] ?? '';
      _pincodeController.text = item['pincode']?.toString() ?? '';
      _emailController.text = item['email'] ?? '';
      _departmentId = item['department_id']?.toString() ?? '64';
      _departmentName = item['department_name'] ?? 'HOME COLLECTION';
      _uploadedFileName = item['photo_id_card'] ?? '';

      if (item['employee_activities'] != null &&
          item['employee_activities']['role_list'] != null &&
          item['employee_activities']['role_list'] is List &&
          (item['employee_activities']['role_list'] as List).isNotEmpty) {
        _selectedRoleIds = List<String>.from(
            item['employee_activities']['role_list'].map((e) => e.toString()));
        final dbService = ref.read(postgresServiceProvider);
        _roleName = await dbService.getRoleNamesByIds(_selectedRoleIds) ?? '';
      } else {
        _roleId = item['role_id']?.toString() ?? '';
        _roleName = item['role_name'] ?? '';
        if (_roleId.isNotEmpty) {
          _selectedRoleIds = [_roleId];
        }
      }

      if (item['allocated_areas'] != null && item['allocated_areas'] is List) {
        _allocatedAreas = List<Map<String, dynamic>>.from(
            item['allocated_areas'].map((e) => Map<String, dynamic>.from(e)));
      }

      setState(() {});
    }
  }

  bool _isTechnicianRole() {
    return _roleName.toUpperCase().contains('TECHNICIAN');
  }

  Future<void> _validate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final dbService = ref.read(postgresServiceProvider);
      final result = await dbService.getUserWithMobile(_mobileController.text);

      if (widget.isEdit) {
        if (result is List && result.isNotEmpty) {
          if (result[0]['emp_id'].toString() != _empId) {
            _showMessageDialog(
                'Error', '${_mobileController.text} Mobile already exists');
            setState(() => _loading = false);
            return;
          }
        }
      } else {
        if (result is List && result.isNotEmpty) {
          _showMessageDialog(
              'Error', '${_mobileController.text} Mobile already exists');
          setState(() => _loading = false);
          return;
        }
      }

      await _uploadAndSave();
    } catch (e) {
      _showMessageDialog('Error', 'Error validating user: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadAndSave() async {
    String key = '';

    if (_selectedFile != null) {
      try {
        final storage = ref.read(storageServiceProvider);
        final jwtToken = storage.getFromSession("pg_admin") ?? "";
        key = "homecollection/id_card/${_selectedFile!.name}";

        late MultipartFile multipartFile;

        if (kIsWeb) {
          if (_selectedFile!.bytes != null) {
            multipartFile = MultipartFile.fromBytes(
              _selectedFile!.bytes!,
              filename: _selectedFile!.name,
            );
          } else {
            throw Exception('File bytes are null');
          }
        } else {
          if (_selectedFile!.path != null) {
            multipartFile = await MultipartFile.fromFile(
              _selectedFile!.path!,
              filename: _selectedFile!.name,
            );
          } else {
            throw Exception('File path is null');
          }
        }

        final formData = FormData.fromMap({
          'upload_file': multipartFile,
          'key': key,
          'bucket_name': 'andersonemployees',
          'jwt_token': jwtToken,
        });

        final dio = Dio();
        final response = await dio.post(
          '${Settings.nodeUrl}/s3/upload_file_v3',
          data: formData,
        );

        if (response.statusCode != 200) {
          throw Exception('Upload failed: ${response.statusMessage}');
        }

        debugPrint('✅ File uploaded successfully: $key');
      } catch (e) {
        _showMessageDialog('Error', 'Error uploading file: $e');
        setState(() => _loading = false);
        return;
      }
    } else if (widget.isEdit && _uploadedFileName.isNotEmpty) {
      key = _uploadedFileName;
    } else {
      key = 'No ID Card';
    }

    await _save(key);
  }

  Future<void> _save(String key) async {
    final storage = ref.read(storageServiceProvider);
    final loggedInName = storage.getFromSession("logged_in_emp_name") ?? "";

    final doc = {
      'first_name': _toTitleCase(_firstNameController.text),
      'last_name': _toTitleCase(_lastNameController.text),
      'department_id': _departmentId,
      'default_tenant_id': _centerId,
      'mobile': _mobileController.text,
      'email': _emailController.text,
      'address': _toTitleCase(_addressController.text),
      'pincode': _pincodeController.text,
      'created_by': loggedInName,
      'last_updated_by': loggedInName,
    };

    if (_rolesModified && _selectedRoles.isNotEmpty) {
      final technicianRole = _selectedRoles.firstWhere(
          (role) => role['role_id'] == 240,
          orElse: () => _selectedRoles.first);
      doc['role_id'] = technicianRole['role_id'].toString();
      final roleList =
          _selectedRoles.map((r) => r['role_id'].toString()).toList();
      doc['employee_activities'] = jsonEncode({'role_list': roleList});
    }

    if (key.isNotEmpty) {
      doc['photo_id_card'] = key;
    }

    Map<String, dynamic> result;
    if (widget.isEdit) {
      result = await ref.read(usersServiceProvider).updateUser(
            _empId,
            doc,
            isTechnician:
                _departmentName == 'HOME COLLECTION' && _isTechnicianRole(),
            allocatedAreas: _allocatedAreas,
          );
    } else {
      result = await ref.read(usersServiceProvider).addUser(
            doc,
            isTechnician:
                _departmentName == 'HOME COLLECTION' && _isTechnicianRole(),
            allocatedAreas: _allocatedAreas,
          );
    }

    setState(() => _loading = false);

    if (result['success'] == true) {
      _showMessageDialog('Success',
          widget.isEdit ? 'Successfully Updated.' : 'Successfully Inserted.',
          onClose: () {
        Navigator.of(context).pop(true);
      });
    } else {
      _showMessageDialog('Error', result['message'] ?? 'Unknown error');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result != null) {
        setState(() => _selectedFile = result.files.first);
      }
    } catch (e) {
      _showMessageDialog('Error', 'Error picking file: $e');
    }
  }

  Future<void> _searchRoles() async {
    setState(() => _overlay = true);
    try {
      final dbService = ref.read(postgresServiceProvider);
      final search = _roleSearchController.text.trim();
      final result =
          await dbService.getRoleList(search.isEmpty ? null : search);

      if (result is List) {
        setState(() {
          _roles = List<Map<String, dynamic>>.from(result);
          _overlay = false;
        });
      } else {
        setState(() {
          _roles = [];
          _overlay = false;
        });
      }
    } catch (e) {
      setState(() {
        _roles = [];
        _overlay = false;
      });
      debugPrint('Error searching roles: $e');
    }
  }

  void _handleRoleSelect(Map<String, dynamic> role, bool? selected) {
    setState(() {
      _rolesModified = true;
      if (selected == true) {
        if (!_selectedRoles.any((r) => r['role_id'] == role['role_id'])) {
          _selectedRoles.add(role);
        }
      } else {
        _selectedRoles.removeWhere((r) => r['role_id'] == role['role_id']);
      }

      final technicianRole = _selectedRoles.firstWhere(
          (r) => r['role_id'] == 240,
          orElse: () => _selectedRoles.isNotEmpty
              ? _selectedRoles.first
              : <String, dynamic>{});

      if (technicianRole.isNotEmpty) {
        _roleId = technicianRole['role_id'].toString();
      }

      _roleName = _selectedRoles.map((r) => r['role_name']).join(', ');
      _selectedRoleIds =
          _selectedRoles.map((r) => r['role_id'].toString()).toList();
    });
  }

  void _removeAllocatedArea(String id) {
    setState(() {
      _allocatedAreas.removeWhere((item) => item['_id'] == id);
    });
  }

  String _toTitleCase(String str) {
    if (str.isEmpty) return "";
    return str.split(' ').map((word) {
      if (word.isEmpty) return "";
      return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
    }).join(' ');
  }

  void _showMessageDialog(String title, String message,
      {VoidCallback? onClose}) {
    final isSuccess = title == 'Success';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (isSuccess ? AppColors.success : AppColors.error)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? AppColors.success : AppColors.error,
                  size: 48,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(title, style: AppTextStyles.h2),
              SizedBox(height: AppSpacing.sm),
              Text(message,
                  textAlign: TextAlign.center, style: AppTextStyles.body),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onClose?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSuccess ? AppColors.success : AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label,
      {IconData? icon, String? prefix, bool required = false}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
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

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: isWideScreen ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
          if (_overlay) _buildLoadingOverlay(),
          if (_showRoleSheet) _buildRoleBottomSheet(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
              widget.isEdit ? 'Edit User' : 'Add User',
              style: AppTextStyles.badge.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
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
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          icon: Icons.person_rounded,
                          title: 'Basic Information',
                          color: AppColors.primary,
                          child: _buildBasicInfoFields(),
                        ),
                        SizedBox(height: AppSpacing.lg),
                        _buildSectionCard(
                          icon: Icons.contact_phone_rounded,
                          title: 'Contact Information',
                          color: AppColors.success,
                          child: _buildContactFields(),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: [
                        _buildSectionCard(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Role & Department',
                          color: AppColors.secondary,
                          child: _buildRoleFields(),
                        ),
                        if (_isTechnicianRole()) ...[
                          SizedBox(height: AppSpacing.lg),
                          _buildSectionCard(
                            icon: Icons.location_on_rounded,
                            title: 'Allocated Areas',
                            color: AppColors.warning,
                            child: _buildAllocatedAreasContent(),
                          ),
                        ],
                        SizedBox(height: AppSpacing.lg),
                        _buildSectionCard(
                          icon: Icons.badge_rounded,
                          title: 'ID Card',
                          color: AppColors.error,
                          child: _buildIdCardContent(),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _buildSectionCard(
            icon: Icons.person_rounded,
            title: 'Basic Information',
            color: AppColors.primary,
            child: _buildBasicInfoFields(),
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
            icon: Icons.admin_panel_settings_rounded,
            title: 'Role & Department',
            color: AppColors.secondary,
            child: _buildRoleFields(),
          ),
          if (_isTechnicianRole()) ...[
            SizedBox(height: AppSpacing.md),
            _buildSectionCard(
              icon: Icons.location_on_rounded,
              title: 'Allocated Areas',
              color: AppColors.warning,
              child: _buildAllocatedAreasContent(),
            ),
          ],
          SizedBox(height: AppSpacing.md),
          _buildSectionCard(
            icon: Icons.badge_rounded,
            title: 'ID Card',
            color: AppColors.error,
            child: _buildIdCardContent(),
          ),
          SizedBox(height: AppSpacing.xl),
          _buildActionButtons(),
          SizedBox(height: AppSpacing.xl),
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
              borderRadius: const BorderRadius.only(
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
                Text(title,
                    style:
                        AppTextStyles.h3.copyWith(color: color, fontSize: 16)),
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

  Widget _buildBasicInfoFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                decoration: _inputDecoration('First Name',
                    icon: Icons.person_outline, required: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'First name is required';
                  }
                  if (value.length > 20) {
                    return 'Name must be less than 20 characters';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                decoration:
                    _inputDecoration('Last Name', icon: Icons.person_outline),
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
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('Mobile',
              icon: Icons.phone_outlined, prefix: '+91 ', required: true),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Mobile is required';
            }
            if (value.length != 10) {
              return 'Mobile number must be 10 digits';
            }
            return null;
          },
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email', icon: Icons.email_outlined),
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration:
              _inputDecoration('Address', icon: Icons.location_on_outlined),
        ),
        SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _pincodeController,
          keyboardType: TextInputType.number,
          decoration:
              _inputDecoration('Pincode', icon: Icons.pin_drop_outlined),
        ),
      ],
    );
  }

  Widget _buildRoleFields() {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _showRoleSheet = true);
            _searchRoles();
          },
          borderRadius: AppRadius.smAll,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.divider),
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: AppColors.textHint, size: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _roleName.isEmpty ? 'Select Role *' : _roleName,
                    style: TextStyle(
                      color: _roleName.isEmpty
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.search, color: AppColors.primary),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border.all(color: AppColors.divider),
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: [
              Icon(Icons.business, color: AppColors.textHint, size: 20),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                    _departmentName.isEmpty ? 'Department' : _departmentName),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            border: Border.all(color: AppColors.divider),
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: [
              Icon(Icons.store, color: AppColors.textHint, size: 20),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(_centerName.isEmpty ? 'Tenant' : _centerName),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllocatedAreasContent() {
    if (_allocatedAreas.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.location_off, color: AppColors.textHint, size: 32),
            SizedBox(height: AppSpacing.sm),
            Text('No allocated areas', style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _allocatedAreas.map((item) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${item['pincode']} ${item['area']}',
                  style: TextStyle(color: AppColors.warning)),
              SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: () => _removeAllocatedArea(item['_id']),
                child: Icon(Icons.close, size: 16, color: AppColors.warning),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIdCardContent() {
    return Column(
      children: [
        if (_uploadedFileName.isNotEmpty)
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            margin: EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: AppRadius.smAll,
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Uploaded: ${_uploadedFileName.split('/').last}',
                    style: TextStyle(color: AppColors.success),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          icon: Icon(_selectedFile != null ? Icons.check : Icons.attach_file,
              color: _selectedFile != null
                  ? AppColors.success
                  : AppColors.secondary),
          label: Text(
            _selectedFile != null ? _selectedFile!.name : 'Attach ID Card',
            style: TextStyle(
                color: _selectedFile != null
                    ? AppColors.success
                    : AppColors.secondary),
          ),
          onPressed: _pickFile,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: _selectedFile != null
                    ? AppColors.success
                    : AppColors.secondary),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
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
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _validate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : Text(widget.isEdit ? 'Update' : 'Save',
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
                  onPressed: _loading ? null : _validate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : Text(widget.isEdit ? 'Update' : 'Save',
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

  Widget _buildRoleBottomSheet() {
    return Container(
      color: Colors.black54,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider),
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: AppPadding.badge,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text('Search Role',
                          style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: _roleSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search roles...',
                          prefixIcon:
                              Icon(Icons.search, color: AppColors.textHint),
                          filled: true,
                          fillColor: AppColors.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.smAll,
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                        ),
                        onChanged: (_) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(
                              const Duration(milliseconds: 500), _searchRoles);
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textHint),
                      onPressed: () => setState(() => _showRoleSheet = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _roles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                color: AppColors.textHint, size: 48),
                            SizedBox(height: AppSpacing.sm),
                            Text('No roles found',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _roles.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppColors.divider),
                        itemBuilder: (context, index) {
                          final role = _roles[index];
                          final isSelected = _selectedRoles
                              .any((r) => r['role_id'] == role['role_id']);
                          return ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (selected) =>
                                  _handleRoleSelect(role, selected),
                            ),
                            title: Text(role['role_name'] ?? '',
                                style: AppTextStyles.body),
                            subtitle: Text('ID: ${role['role_id']}',
                                style: AppTextStyles.caption),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: AppColors.success)
                                : null,
                            onTap: () => _handleRoleSelect(role, !isSelected),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

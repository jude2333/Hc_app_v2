// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:dio/dio.dart';
// import 'dart:async';
// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/foundation.dart' show kIsWeb;
// // import 'dart:html' as html;
// import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';

// // Import your services
// import 'package:anderson_crm_flutter/providers/storage_provider.dart';
// import 'package:anderson_crm_flutter/services/postgresService.dart';
// import '../config/settings.dart';

// class AddEditUserPage extends ConsumerStatefulWidget {
//   final Map<String, dynamic>? userData;
//   final bool isEdit;

//   const AddEditUserPage({
//     Key? key,
//     this.userData,
//     this.isEdit = false,
//   }) : super(key: key);

//   @override
//   ConsumerState<AddEditUserPage> createState() => _AddEditUserPageState();
// }

// class _AddEditUserPageState extends ConsumerState<AddEditUserPage> {
//   final _formKey = GlobalKey<FormState>();
//   Timer? _debounceTimer;

//   // Form controllers
//   final TextEditingController _firstNameController = TextEditingController();
//   final TextEditingController _lastNameController = TextEditingController();
//   final TextEditingController _mobileController = TextEditingController();
//   final TextEditingController _addressController = TextEditingController();
//   final TextEditingController _pincodeController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _roleSearchController = TextEditingController();

//   // State variables
//   bool _loading = false;
//   bool _overlay = false;
//   String _empId = '';
//   String _roleId = '';
//   String _roleName = '';
//   List<String> _selectedRoleIds = [];
//   List<Map<String, dynamic>> _selectedRoles = [];
//   String _departmentId = '64';
//   String _departmentName = 'HOME COLLECTION';
//   String _centerId = '';
//   String _centerName = '';
//   List<Map<String, dynamic>> _allocatedAreas = [];
//   PlatformFile? _selectedFile;
//   String _uploadedFileName = '';
//   bool _rolesModified = false;

//   // Bottom sheets
//   bool _showRoleSheet = false;
//   List<Map<String, dynamic>> _roles = [];

//   @override
//   void initState() {
//     super.initState();
//     _initializeData();
//   }

//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _mobileController.dispose();
//     _addressController.dispose();
//     _pincodeController.dispose();
//     _emailController.dispose();
//     _roleSearchController.dispose();
//     _debounceTimer?.cancel();
//     super.dispose();
//   }

//   Future<void> _initializeData() async {
//     final storage = ref.read(storageServiceProvider);
//     _centerId = storage.getFromSession("logged_in_tenant_id") ?? "";
//     _centerName = storage.getFromSession("logged_in_tenant_name") ?? "";

//     if (widget.isEdit && widget.userData != null) {
//       final item = widget.userData!;
//       _empId = item['emp_id']?.toString() ?? '';
//       _firstNameController.text = item['first_name'] ?? '';
//       _lastNameController.text = item['last_name'] ?? '';
//       _mobileController.text = item['mobile'] ?? '';
//       _addressController.text = item['address'] ?? '';
//       _pincodeController.text = item['pincode']?.toString() ?? '';
//       _emailController.text = item['email'] ?? '';
//       _departmentId = item['department_id']?.toString() ?? '64';
//       _departmentName = item['department_name'] ?? 'HOME COLLECTION';
//       _uploadedFileName = item['photo_id_card'] ?? '';

//       // Handle roles
//       if (item['employee_activities'] != null &&
//           item['employee_activities']['role_list'] != null &&
//           item['employee_activities']['role_list'] is List &&
//           (item['employee_activities']['role_list'] as List).isNotEmpty) {
//         _selectedRoleIds = List<String>.from(
//             item['employee_activities']['role_list'].map((e) => e.toString()));
//         final dbService = ref.read(postgresServiceProvider);
//         _roleName = await dbService.getRoleNamesByIds(_selectedRoleIds) ?? '';
//       } else {
//         _roleId = item['role_id']?.toString() ?? '';
//         _roleName = item['role_name'] ?? '';
//         if (_roleId.isNotEmpty) {
//           _selectedRoleIds = [_roleId];
//         }
//       }

//       // Handle allocated areas
//       if (item['allocated_areas'] != null && item['allocated_areas'] is List) {
//         _allocatedAreas = List<Map<String, dynamic>>.from(
//             item['allocated_areas'].map((e) => Map<String, dynamic>.from(e)));
//       }

//       setState(() {});
//     }
//   }

//   bool _isTechnicianRole() {
//     return _roleName.toUpperCase().contains('TECHNICIAN');
//   }

//   Future<void> _validate() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }

//     setState(() => _loading = true);

//     try {
//       final dbService = ref.read(postgresServiceProvider);
//       final result = await dbService.getUserWithMobile(_mobileController.text);

//       if (widget.isEdit) {
//         if (result is List && result.isNotEmpty) {
//           if (result[0]['emp_id'].toString() != _empId) {
//             _showMessageDialog(
//                 'Error', '${_mobileController.text} Mobile already exists');
//             setState(() => _loading = false);
//             return;
//           }
//         }
//       } else {
//         if (result is List && result.isNotEmpty) {
//           _showMessageDialog(
//               'Error', '${_mobileController.text} Mobile already exists');
//           setState(() => _loading = false);
//           return;
//         }
//       }

//       await _uploadAndSave();
//     } catch (e) {
//       _showMessageDialog('Error', 'Error validating user: $e');
//       setState(() => _loading = false);
//     }
//   }

//   // Future<void> _uploadAndSave() async {
//   //   String key = '';

//   //   if (_selectedFile != null) {
//   //     try {
//   //       final storage = ref.read(storageServiceProvider);
//   //       final jwtToken = storage.getFromSession("pg_admin") ?? "";
//   //       key = "homecollection/id_card/${_selectedFile!.name}";

//   //       final formData = FormData.fromMap({
//   //         'upload_file': kIsWeb
//   //             ? MultipartFile.fromBytes(_selectedFile!.bytes!,
//   //                 filename: _selectedFile!.name)
//   //             : await MultipartFile.fromFile(_selectedFile!.path!,
//   //                 filename: _selectedFile!.name),
//   //         'key': key,
//   //         'bucket_name': 'andersonemployees',
//   //         'jwt_token': jwtToken,
//   //       });

//   //       final dio = Dio();
//   //       final response = await dio.post(
//   //         '${Settings.nodeUrl}/s3/upload_file_v3',
//   //         data: formData,
//   //       );

//   //       if (response.statusCode != 200) {
//   //         throw Exception('Upload failed: ${response.statusMessage}');
//   //       }
//   //     } catch (e) {
//   //       _showMessageDialog('Error', 'Error uploading file: $e');
//   //       setState(() => _loading = false);
//   //       return;
//   //     }
//   //   } else if (widget.isEdit) {
//   //     key = '';
//   //   } else {
//   //     key = 'No ID Card';
//   //   }

//   //   await _save(key);
//   // }

//   Future<void> _uploadAndSave() async {
//     String key = '';

//     if (_selectedFile != null) {
//       try {
//         final storage = ref.read(storageServiceProvider);
//         final jwtToken = storage.getFromSession("pg_admin") ?? "";
//         key = "homecollection/id_card/${_selectedFile!.name}";

//         // Create FormData - different approach for web vs mobile
//         late MultipartFile multipartFile;

//         if (kIsWeb) {
//           // Web platform - use bytes directly
//           if (_selectedFile!.bytes != null) {
//             multipartFile = MultipartFile.fromBytes(
//               _selectedFile!.bytes!,
//               filename: _selectedFile!.name,
//             );
//           } else {
//             throw Exception('File bytes are null');
//           }
//         } else {
//           // Mobile platform - use file path
//           if (_selectedFile!.path != null) {
//             multipartFile = await MultipartFile.fromFile(
//               _selectedFile!.path!,
//               filename: _selectedFile!.name,
//             );
//           } else {
//             throw Exception('File path is null');
//           }
//         }

//         final formData = FormData.fromMap({
//           'upload_file': multipartFile,
//           'key': key,
//           'bucket_name': 'andersonemployees',
//           'jwt_token': jwtToken,
//         });

//         final dio = Dio();
//         final response = await dio.post(
//           '${Settings.nodeUrl}/s3/upload_file_v3',
//           data: formData,
//         );

//         if (response.statusCode != 200) {
//           throw Exception('Upload failed: ${response.statusMessage}');
//         }

//         debugPrint('✅ File uploaded successfully: $key');
//       } catch (e) {
//         _showMessageDialog('Error', 'Error uploading file: $e');
//         setState(() => _loading = false);
//         return;
//       }
//     } else if (widget.isEdit && _uploadedFileName.isNotEmpty) {
//       // Keep existing file if editing and no new file selected
//       key = _uploadedFileName;
//     } else {
//       key = 'No ID Card';
//     }

//     await _save(key);
//   }

//   Future<void> _save(String key) async {
//     final storage = ref.read(storageServiceProvider);
//     final loggedInName = storage.getFromSession("logged_in_emp_name") ?? "";

//     final doc = {
//       'first_name': _toTitleCase(_firstNameController.text),
//       'last_name': _toTitleCase(_lastNameController.text),
//       'department_id': _departmentId,
//       'default_tenant_id': _centerId,
//       'mobile': _mobileController.text,
//       'email': _emailController.text,
//       'address': _toTitleCase(_addressController.text),
//       'pincode': _pincodeController.text,
//       'created_by': loggedInName,
//       'last_updated_by': loggedInName,
//     };

//     if (_rolesModified && _selectedRoles.isNotEmpty) {
//       // Find technician role
//       final technicianRole = _selectedRoles.firstWhere(
//           (role) => role['role_id'] == 240,
//           orElse: () => _selectedRoles.first);
//       doc['role_id'] = technicianRole['role_id'];
//       final roleList =
//           _selectedRoles.map((r) => r['role_id'].toString()).toList();
//       // Store employee_activities as a JSON string to match expected String type
//       doc['employee_activities'] = jsonEncode({'role_list': roleList});
//     }

//     if (widget.isEdit) {
//       if (key.isNotEmpty) {
//         doc['photo_id_card'] = key;
//       }
//       await _doUpdate(doc);
//     } else {
//       doc['photo_id_card'] = key;
//       await _doInsert(doc);
//     }
//   }

//   Future<void> _doUpdate(Map<String, dynamic> doc) async {
//     try {
//       final dbService = ref.read(postgresServiceProvider);
//       final result = await dbService.updateUser(_empId, doc);

//       if (result.statusCode == 200 || result.statusCode == 204) {
//         if (_departmentName == 'HOME COLLECTION' && _isTechnicianRole()) {
//           final allocDoc = {
//             'emp_id': _empId,
//             'allocated_areas': jsonEncode(_allocatedAreas),
//             'created_by': doc['created_by'],
//             'last_updated_by': doc['last_updated_by'],
//           };
//           await dbService.upsertAllocatedAreas(_empId, allocDoc);
//         }

//         setState(() => _loading = false);
//         _showMessageDialog('Success', 'Successfully Updated.', onClose: () {
//           Navigator.of(context).pop(true);
//         });
//       } else {
//         setState(() => _loading = false);
//         _showMessageDialog('Error', 'Problem in updation');
//       }
//     } catch (e) {
//       setState(() => _loading = false);
//       if (e.toString().contains('409')) {
//         _showMessageDialog('Error',
//             'Mobile number found in deleted user. Please contact Admin.');
//       } else {
//         _showMessageDialog('Error', 'Problem in updation: $e');
//       }
//     }
//   }

//   Future<void> _doInsert(Map<String, dynamic> doc) async {
//     try {
//       final dbService = ref.read(postgresServiceProvider);
//       final result = await dbService.insertUser(doc);

//       if (result.statusCode == 201) {
//         final searchResult = await dbService.searchEmployee(doc['mobile']);

//         if (searchResult is List &&
//             searchResult.isNotEmpty &&
//             searchResult[0]['emp_id'] != null) {
//           final empId = searchResult[0]['emp_id'].toString();

//           if (_departmentName == 'HOME COLLECTION' && _isTechnicianRole()) {
//             final allocDoc = {
//               'emp_id': empId,
//               'allocated_areas': jsonEncode(_allocatedAreas),
//               'created_by': doc['created_by'],
//               'last_updated_by': doc['last_updated_by'],
//             };
//             await dbService.upsertAllocatedAreas(empId, allocDoc);
//           }
//         }

//         setState(() => _loading = false);
//         _showMessageDialog('Success', 'Successfully Inserted.', onClose: () {
//           Navigator.of(context).pop(true);
//         });
//       } else {
//         setState(() => _loading = false);
//         _showMessageDialog('Error', 'Problem while adding new record.');
//       }
//     } catch (e) {
//       setState(() => _loading = false);
//       if (e.toString().contains('409')) {
//         _showMessageDialog('Error',
//             'Mobile number found in deleted user. Please contact Admin.');
//       } else {
//         _showMessageDialog('Error', 'Problem while adding new record: $e');
//       }
//     }
//   }

//   Future<void> _pickFile() async {
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
//       );

//       if (result != null) {
//         setState(() {
//           _selectedFile = result.files.first;
//         });
//       }
//     } catch (e) {
//       _showMessageDialog('Error', 'Error picking file: $e');
//     }
//   }

//   Future<void> _searchRoles() async {
//     setState(() => _overlay = true);
//     try {
//       final dbService = ref.read(postgresServiceProvider);
//       final search = _roleSearchController.text.trim();
//       final result =
//           await dbService.getRoleList(search.isEmpty ? null : search);

//       if (result is List) {
//         setState(() {
//           _roles = List<Map<String, dynamic>>.from(result);
//           _overlay = false;
//         });
//       } else {
//         setState(() {
//           _roles = [];
//           _overlay = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _roles = [];
//         _overlay = false;
//       });
//       debugPrint('Error searching roles: $e');
//     }
//   }

//   void _handleRoleSelect(Map<String, dynamic> role, bool? selected) {
//     setState(() {
//       _rolesModified = true;
//       if (selected == true) {
//         if (!_selectedRoles.any((r) => r['role_id'] == role['role_id'])) {
//           _selectedRoles.add(role);
//         }
//       } else {
//         _selectedRoles.removeWhere((r) => r['role_id'] == role['role_id']);
//       }

//       // Update role ID and name
//       final technicianRole = _selectedRoles.firstWhere(
//           (r) => r['role_id'] == 240,
//           orElse: () => _selectedRoles.isNotEmpty
//               ? _selectedRoles.first
//               : <String, dynamic>{});

//       if (technicianRole.isNotEmpty) {
//         _roleId = technicianRole['role_id'].toString();
//       }

//       _roleName = _selectedRoles.map((r) => r['role_name']).join(', ');
//       _selectedRoleIds =
//           _selectedRoles.map((r) => r['role_id'].toString()).toList();
//     });
//   }

//   void _removeAllocatedArea(String id) {
//     setState(() {
//       _allocatedAreas.removeWhere((item) => item['_id'] == id);
//     });
//   }

//   String _toTitleCase(String str) {
//     if (str.isEmpty) return "";
//     return str.split(' ').map((word) {
//       if (word.isEmpty) return "";
//       return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
//     }).join(' ');
//   }

//   void _showMessageDialog(String title, String message,
//       {VoidCallback? onClose}) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Container(
//           color: Colors.orange,
//           padding: const EdgeInsets.all(16),
//           child: Text(
//             title,
//             style: const TextStyle(color: Colors.white),
//           ),
//         ),
//         content: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Text(message, style: const TextStyle(fontSize: 18)),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               onClose?.call();
//             },
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         leading: IconButton(
//           icon: const Icon(Icons.close, color: Colors.black),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           decoration: BoxDecoration(
//             color: Colors.orange,
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: Text(
//             widget.isEdit ? 'Edit User' : 'Add User',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           SingleChildScrollView(
//             padding: const EdgeInsets.all(16),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   _buildBasicInfoSection(),
//                   const SizedBox(height: 24),
//                   _buildContactSection(),
//                   const SizedBox(height: 24),
//                   _buildRoleSection(),
//                   const SizedBox(height: 24),
//                   if (_isTechnicianRole()) ...[
//                     _buildAllocatedAreasSection(),
//                     const SizedBox(height: 24),
//                   ],
//                   _buildIdCardSection(),
//                   const SizedBox(height: 32),
//                   _buildActionButtons(),
//                 ],
//               ),
//             ),
//           ),
//           if (_overlay)
//             Container(
//               color: Colors.black54,
//               child: const Center(
//                 child: CircularProgressIndicator(),
//               ),
//             ),
//           if (_showRoleSheet) _buildRoleBottomSheet(),
//         ],
//       ),
//     );
//   }

//   Widget _buildBasicInfoSection() {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Basic Information',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     controller: _firstNameController,
//                     decoration: const InputDecoration(
//                       labelText: 'First Name *',
//                       hintText: 'Enter first name',
//                       border: OutlineInputBorder(),
//                     ),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'First name is required';
//                       }
//                       if (value.length > 20) {
//                         return 'Name must be less than 20 characters';
//                       }
//                       return null;
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: TextFormField(
//                     controller: _lastNameController,
//                     decoration: const InputDecoration(
//                       labelText: 'Last Name',
//                       hintText: 'Enter last name',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildContactSection() {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Contact Information',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _mobileController,
//               keyboardType: TextInputType.phone,
//               decoration: const InputDecoration(
//                 labelText: 'Mobile *',
//                 hintText: 'Enter mobile number',
//                 prefixText: '+91 ',
//                 border: OutlineInputBorder(),
//               ),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Mobile is required';
//                 }
//                 if (value.length != 10) {
//                   return 'Mobile number must be 10 digits';
//                 }
//                 if (int.tryParse(value) == null || int.parse(value) <= 0) {
//                   return 'Mobile number must be greater than 0';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _emailController,
//               keyboardType: TextInputType.emailAddress,
//               decoration: const InputDecoration(
//                 labelText: 'Email',
//                 hintText: 'Enter email address',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _addressController,
//               maxLines: 2,
//               decoration: const InputDecoration(
//                 labelText: 'Address',
//                 hintText: 'Enter address',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               controller: _pincodeController,
//               keyboardType: TextInputType.number,
//               decoration: const InputDecoration(
//                 labelText: 'Pincode',
//                 hintText: 'Enter pincode',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRoleSection() {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Role & Department',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               readOnly: true,
//               decoration: InputDecoration(
//                 labelText: 'Role Name *',
//                 hintText: 'Choose role name',
//                 border: const OutlineInputBorder(),
//                 suffixIcon: IconButton(
//                   icon: const Icon(Icons.search),
//                   onPressed: () {
//                     setState(() => _showRoleSheet = true);
//                     _searchRoles();
//                   },
//                 ),
//               ),
//               controller: TextEditingController(text: _roleName),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Role is required. Click search icon to choose.';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               readOnly: true,
//               decoration: const InputDecoration(
//                 labelText: 'Department Name *',
//                 hintText: 'Department name',
//                 border: OutlineInputBorder(),
//               ),
//               controller: TextEditingController(text: _departmentName),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Department is required';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 16),
//             TextFormField(
//               readOnly: true,
//               decoration: const InputDecoration(
//                 labelText: 'Tenant Name *',
//                 hintText: 'Tenant name',
//                 border: OutlineInputBorder(),
//               ),
//               controller: TextEditingController(text: _centerName),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Tenant is required';
//                 }
//                 return null;
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAllocatedAreasSection() {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Allocated Collection Areas',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.search, color: Colors.orange),
//                   onPressed: () {
//                     _showMessageDialog('Info',
//                         'Pincode search not implemented yet. Will be added later.');
//                   },
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             if (_allocatedAreas.isEmpty)
//               const Padding(
//                 padding: EdgeInsets.all(16),
//                 child: Text(
//                   'No allocated areas',
//                   style: TextStyle(fontStyle: FontStyle.italic),
//                 ),
//               )
//             else
//               Wrap(
//                 spacing: 8,
//                 runSpacing: 8,
//                 children: _allocatedAreas.map((item) {
//                   return Chip(
//                     label: Text('${item['pincode']} ${item['area']}'),
//                     deleteIcon: const Icon(Icons.close, size: 18),
//                     onDeleted: () => _removeAllocatedArea(item['_id']),
//                     backgroundColor: Colors.orange.shade50,
//                     side: const BorderSide(color: Colors.orange),
//                   );
//                 }).toList(),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildIdCardSection() {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'ID Card',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             if (_uploadedFileName.isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.only(bottom: 8),
//                 child: Chip(
//                   label: Text('Uploaded: $_uploadedFileName'),
//                   backgroundColor: Colors.blue.shade50,
//                 ),
//               ),
//             OutlinedButton.icon(
//               icon: const Icon(Icons.attach_file),
//               label: Text(_selectedFile != null
//                   ? _selectedFile!.name
//                   : 'Attach ID Card Copy'),
//               onPressed: _pickFile,
//               style: OutlinedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 48),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         ElevatedButton(
//           onPressed: _loading ? null : _validate,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.orange,
//             foregroundColor: Colors.white,
//             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//           ),
//           child: _loading
//               ? const SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                   ),
//                 )
//               : Text(widget.isEdit ? 'Update' : 'Save'),
//         ),
//         const SizedBox(width: 16),
//         OutlinedButton(
//           onPressed: () => Navigator.of(context).pop(),
//           style: OutlinedButton.styleFrom(
//             padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//           ),
//           child: const Text('Close'),
//         ),
//       ],
//     );
//   }

//   Widget _buildRoleBottomSheet() {
//     return Container(
//       color: Colors.black54,
//       child: Align(
//         alignment: Alignment.bottomCenter,
//         child: Container(
//           height: MediaQuery.of(context).size.height * 0.6,
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//           ),
//           child: Column(
//             children: [
//               // header bar (already written)
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border(
//                     bottom: BorderSide(color: Colors.grey.shade300),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.orange,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: const Text(
//                         'Search Role',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: TextField(
//                         controller: _roleSearchController,
//                         decoration: const InputDecoration(
//                           hintText: 'Search',
//                           prefixIcon: Icon(Icons.search),
//                           border: OutlineInputBorder(),
//                           contentPadding:
//                               EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                         ),
//                         onChanged: (_) {
//                           _debounceTimer?.cancel();
//                           _debounceTimer = Timer(
//                               const Duration(milliseconds: 500), _searchRoles);
//                         },
//                       ),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.close),
//                       onPressed: () => setState(() => _showRoleSheet = false),
//                     ),
//                   ],
//                 ),
//               ),
//               // role list (CONTINUE FROM HERE)
//               Expanded(
//                 child: _roles.isEmpty
//                     ? const Center(child: Text('No roles found'))
//                     : ListView.builder(
//                         itemCount: _roles.length,
//                         itemBuilder: (context, index) {
//                           final role = _roles[index];
//                           final isSelected = _selectedRoles
//                               .any((r) => r['role_id'] == role['role_id']);
//                           return ListTile(
//                             leading: Checkbox(
//                               value: isSelected,
//                               onChanged: (selected) =>
//                                   _handleRoleSelect(role, selected),
//                             ),
//                             title: Text(role['role_name'] ?? ''),
//                             subtitle: Text('ID: ${role['role_id']}'),
//                             onTap: () => _handleRoleSelect(role, !isSelected),
//                           );
//                         },
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

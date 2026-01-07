// import 'dart:convert';
// import 'dart:io';
// import 'package:anderson_crm_flutter/database/work_orderDb.dart';
// import 'package:anderson_crm_flutter/features/core/util.dart';
// import 'package:anderson_crm_flutter/services/postgresService.dart';
// import 'package:anderson_crm_flutter/providers/storage_provider.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:dio/dio.dart';

// final _b2bClientsPod = StateProvider<List<Map<String, dynamic>>>((_) => []);
// final _selectedClientPod = StateProvider<Map<String, dynamic>?>((_) => null);

// class AddWorkOrderPage extends ConsumerStatefulWidget {
//   const AddWorkOrderPage({Key? key}) : super(key: key);

//   @override
//   ConsumerState<AddWorkOrderPage> createState() => _AddWorkOrderPageState();
// }

// class _AddWorkOrderPageState extends ConsumerState<AddWorkOrderPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _imagePicker = ImagePicker();

//   String _collectionDate = '';
//   TimeOfDay? _collectionTime;
//   String _salutation = '';
//   String _name = '';
//   String _age = 'NA';
//   String _gender = '';
//   String _mobile = '';
//   String _address = 'NA';
//   String _pincode = '';
//   String _email = 'NA';
//   String _doctor = '';
//   String _freeText = '';
//   bool _vip = false;
//   bool _urgent = false;
//   int _credit = 0;
//   String _creditSelect = 'None';
//   bool _b2b = false;

//   bool _msgSms = true;
//   bool _msgWhatsapp = true;
//   bool _msgEmail = true;

//   XFile? _prescriptionImage;
//   String _imageSrc = '';
//   String _fileName = '';
//   String _fileLocation = '';

//   bool _isLoading = false;
//   bool _isInitialized = false;
//   bool _hasAttemptedValidation = false;

//   List<String> _suitableDates = [];

//   @override
//   void initState() {
//     super.initState();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _initializeDates();
//     });
//   }

//   void _initializeDates() {
//     if (!mounted) return;
//     setState(() {
//       for (int i = 0; i <= 9; i++) {
//         _suitableDates.add(Util.getWeekDay(i));
//       }
//       _collectionDate = _suitableDates.isNotEmpty ? _suitableDates[0] : '';
//       _isInitialized = true;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedClient = ref.watch(_selectedClientPod);

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         leading: IconButton(
//           icon: const Icon(Icons.close),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Colors.orange,
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: const Text(
//             'Add Work Order',
//             style: TextStyle(
//                 color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: _showSettingsDialog,
//             child: const Text('Settings', style: TextStyle(fontSize: 12)),
//           ),
//         ],
//       ),
//       body: _isInitialized
//           ? Stack(
//               children: [
//                 SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         LayoutBuilder(
//                           builder: (context, constraints) {
//                             if (constraints.maxWidth < 600) {
//                               return _buildMobileLayout(selectedClient);
//                             } else {
//                               return _buildDesktopLayout(selectedClient);
//                             }
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 if (_isLoading)
//                   Container(
//                     color: Colors.black26,
//                     child: const Center(
//                       child: CircularProgressIndicator(),
//                     ),
//                   ),
//               ],
//             )
//           : const Center(child: CircularProgressIndicator()),
//     );
//   }

//   Widget _buildMobileLayout(Map<String, dynamic>? selectedClient) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         DropdownButtonFormField<String>(
//           value: _collectionDate.isNotEmpty ? _collectionDate : null,
//           decoration: const InputDecoration(
//             labelText: 'Choose Collection Date',
//             border: OutlineInputBorder(),
//             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//           items: _suitableDates.map((date) {
//             return DropdownMenuItem(
//                 value: date,
//                 child: Text(date, style: const TextStyle(fontSize: 14)));
//           }).toList(),
//           onChanged: (value) => setState(() => _collectionDate = value!),
//         ),
//         const SizedBox(height: 12),
//         InkWell(
//           onTap: () => _selectTime(context),
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border.all(
//                 color: _hasAttemptedValidation && _collectionTime == null
//                     ? Colors.red
//                     : Colors.grey,
//               ),
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: InputDecorator(
//               decoration: const InputDecoration(
//                 labelText: 'Choose Collection Time',
//                 border: InputBorder.none,
//                 contentPadding:
//                     EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 prefixIcon: Icon(Icons.access_time),
//               ),
//               child: Text(
//                 _collectionTime?.format(context) ?? 'Select time',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: _collectionTime == null ? Colors.grey : Colors.black,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         if (_hasAttemptedValidation && _collectionTime == null)
//           const Padding(
//             padding: EdgeInsets.only(left: 12, top: 4),
//             child: Text(
//               'Please select collection time',
//               style: TextStyle(color: Colors.red, fontSize: 12),
//             ),
//           ),
//         const SizedBox(height: 12),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Upload prescription photo',
//                 style: TextStyle(fontSize: 12)),
//             const SizedBox(height: 4),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.camera_alt, size: 18),
//               label: const Text('Choose', style: TextStyle(fontSize: 12)),
//               onPressed: _pickImage,
//               style: ElevatedButton.styleFrom(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               ),
//             ),
//             if (_prescriptionImage != null) ...[
//               const SizedBox(height: 8),
//               Container(
//                 width: double.infinity,
//                 height: 200,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(4),
//                   child: kIsWeb
//                       ? Image.network(_imageSrc, fit: BoxFit.cover)
//                       : Image.file(File(_prescriptionImage!.path),
//                           fit: BoxFit.cover),
//                 ),
//               ),
//             ],
//           ],
//         ),
//         const SizedBox(height: 16),
//         _buildNameSection(),
//         const SizedBox(height: 16),
//         _buildContactSection(),
//         const SizedBox(height: 16),
//         _buildDoctorSection(selectedClient),
//         const SizedBox(height: 24),
//         _buildActionButtons(),
//         const SizedBox(height: 24),
//       ],
//     );
//   }

//   Widget _buildDesktopLayout(Map<String, dynamic>? selectedClient) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Expanded(
//               flex: 2,
//               child: DropdownButtonFormField<String>(
//                 value: _collectionDate.isNotEmpty ? _collectionDate : null,
//                 decoration: const InputDecoration(
//                   labelText: 'Choose Collection Date',
//                   border: OutlineInputBorder(),
//                   contentPadding:
//                       EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//                 items: _suitableDates.map((date) {
//                   return DropdownMenuItem(
//                       value: date,
//                       child: Text(date, style: const TextStyle(fontSize: 14)));
//                 }).toList(),
//                 onChanged: (value) => setState(() => _collectionDate = value!),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               flex: 2,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   InkWell(
//                     onTap: () => _selectTime(context),
//                     child: Container(
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color:
//                               _hasAttemptedValidation && _collectionTime == null
//                                   ? Colors.red
//                                   : Colors.grey,
//                         ),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: InputDecorator(
//                         decoration: const InputDecoration(
//                           labelText: 'Choose Collection Time',
//                           border: InputBorder.none,
//                           contentPadding:
//                               EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                           prefixIcon: Icon(Icons.access_time),
//                         ),
//                         child: Text(
//                           _collectionTime?.format(context) ?? 'Select time',
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: _collectionTime == null
//                                 ? Colors.grey
//                                 : Colors.black,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   if (_hasAttemptedValidation && _collectionTime == null)
//                     const Padding(
//                       padding: EdgeInsets.only(left: 12, top: 4),
//                       child: Text(
//                         'Please select collection time',
//                         style: TextStyle(color: Colors.red, fontSize: 12),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               flex: 2,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Upload prescription photo',
//                       style: TextStyle(fontSize: 12)),
//                   const SizedBox(height: 4),
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.camera_alt, size: 18),
//                     label: const Text('Choose', style: TextStyle(fontSize: 12)),
//                     onPressed: _pickImage,
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 12, vertical: 8),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 12),
//             if (_prescriptionImage != null)
//               Container(
//                 width: 100,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(4),
//                   child: kIsWeb
//                       ? Image.network(_imageSrc, fit: BoxFit.cover)
//                       : Image.file(File(_prescriptionImage!.path),
//                           fit: BoxFit.cover),
//                 ),
//               ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         _buildNameSection(),
//         const SizedBox(height: 16),
//         _buildContactSection(),
//         const SizedBox(height: 16),
//         _buildDoctorSection(selectedClient),
//         const SizedBox(height: 24),
//         _buildActionButtons(),
//         const SizedBox(height: 24),
//       ],
//     );
//   }

//   Widget _buildNameSection() {
//     return Row(
//       children: [
//         Expanded(
//           flex: 1,
//           child: DropdownButtonFormField<String>(
//             value: _salutation.isEmpty ? null : _salutation,
//             decoration: const InputDecoration(
//               labelText: 'Salutation',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             items: ['Mr', 'Ms', 'Mrs', 'Child Of', 'Dr']
//                 .map((s) => DropdownMenuItem(value: s, child: Text(s)))
//                 .toList(),
//             onChanged: (value) {
//               setState(() {
//                 _salutation = value!;
//                 _updateGenderFromSalutation();
//               });
//             },
//             validator: (v) => v == null ? 'Required' : null,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 3,
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Name',
//               hintText: 'Name',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             onChanged: (v) => _name = v,
//             validator: (v) {
//               if (v == null || v.isEmpty) return 'Name is required';
//               if (v.length > 30) return 'Max 30 characters';
//               return null;
//             },
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 1,
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Age',
//               hintText: 'Age',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             initialValue: _age,
//             onChanged: (v) => _age = v,
//             validator: (v) {
//               if (v == null || v.isEmpty) return 'Required';
//               if (v.length > 10) return 'Max 10 characters';
//               return null;
//             },
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 1,
//           child: DropdownButtonFormField<String>(
//             value: _gender.isEmpty ? null : _gender,
//             decoration: const InputDecoration(
//               labelText: 'Gender',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             items: ['Male', 'Female', 'Other']
//                 .map((g) => DropdownMenuItem(value: g, child: Text(g)))
//                 .toList(),
//             onChanged: (value) => setState(() => _gender = value!),
//             validator: (v) => v == null ? 'Required' : null,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildContactSection() {
//     return Row(
//       children: [
//         Expanded(
//           flex: 1,
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Mobile',
//               hintText: 'Mobile',
//               border: OutlineInputBorder(),
//               prefixText: '+91 ',
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             keyboardType: TextInputType.phone,
//             maxLength: 10,
//             onChanged: (v) => _mobile = v,
//             validator: (v) {
//               if (v == null || v.isEmpty) return 'Mobile is required';
//               if (v.length != 10) return 'Must be 10 digits';
//               return null;
//             },
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 2,
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Address',
//               hintText: 'Address',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             initialValue: _address,
//             onChanged: (v) => _address = v,
//             validator: (v) {
//               if (v == null || v.isEmpty) return 'Address is required';
//               if (v.length > 100) return 'Max 100 characters';
//               return null;
//             },
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 2,
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Email',
//               hintText: 'Email',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             initialValue: _email,
//             keyboardType: TextInputType.emailAddress,
//             onChanged: (v) => _email = v,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Pincode',
//               hintText: 'Pincode',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             keyboardType: TextInputType.number,
//             maxLength: 6,
//             onChanged: (v) => _pincode = v,
//             validator: (v) {
//               if (v == null || v.isEmpty) return 'Required';
//               if (v.length != 6) return 'Must be 6 digits';
//               return null;
//             },
//           ),
//         ),
//         const SizedBox(width: 8),
//         IconButton(
//           icon: const Icon(Icons.search),
//           onPressed: () {
//             _showSnackBar('Pincode search not implemented yet');
//           },
//           tooltip: 'Search Pincode',
//         ),
//       ],
//     );
//   }

//   Widget _buildDoctorSection(Map<String, dynamic>? selectedClient) {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final isMobile = constraints.maxWidth < 600;

//         if (isMobile) {
//           return _buildDoctorSectionMobile(selectedClient);
//         } else {
//           return _buildDoctorSectionDesktop(selectedClient);
//         }
//       },
//     );
//   }

//   Widget _buildDoctorSectionMobile(Map<String, dynamic>? selectedClient) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         TextFormField(
//           decoration: const InputDecoration(
//             labelText: 'Doctor Name',
//             hintText: 'Doctor Name',
//             border: OutlineInputBorder(),
//             prefixText: 'Dr. ',
//             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//           onChanged: (v) => _doctor = v,
//         ),
//         const SizedBox(height: 16),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: ListTile(
//             title: const Text('B2B?', style: TextStyle(fontSize: 14)),
//             trailing: Switch(
//               value: _b2b,
//               onChanged: (v) {
//                 setState(() => _b2b = v);
//                 if (v) {
//                   _showB2BClientDialog();
//                 } else {
//                   ref.read(_selectedClientPod.notifier).state = null;
//                   setState(() {
//                     _msgSms = true;
//                     _msgWhatsapp = true;
//                     _msgEmail = true;
//                   });
//                 }
//               },
//             ),
//             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
//           ),
//         ),
//         if (selectedClient != null) ...[
//           const SizedBox(height: 12),
//           TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Selected B2B Client',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             ),
//             readOnly: true,
//             controller: TextEditingController(
//               text:
//                   '${selectedClient['first_name']} ${selectedClient['last_name']} (${selectedClient['client_master']['client_name']})',
//             ),
//           ),
//         ],
//         const SizedBox(height: 16),
//         TextFormField(
//           decoration: const InputDecoration(
//             labelText: 'Free text',
//             hintText: 'Free text',
//             border: OutlineInputBorder(),
//             contentPadding: EdgeInsets.all(12),
//           ),
//           maxLines: 3,
//           onChanged: (v) => _freeText = v,
//         ),
//         const SizedBox(height: 16),
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey.shade300),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Column(
//             children: [
//               Padding(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('VIP Client?', style: TextStyle(fontSize: 14)),
//                     Switch(
//                       value: _vip,
//                       onChanged: (v) => setState(() => _vip = v),
//                     ),
//                   ],
//                 ),
//               ),
//               const Divider(height: 1),
//               Padding(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Urgent?', style: TextStyle(fontSize: 14)),
//                     Switch(
//                       value: _urgent,
//                       onChanged: (v) => setState(() => _urgent = v),
//                     ),
//                   ],
//                 ),
//               ),
//               const Divider(height: 1),
//               Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: DropdownButtonFormField<String>(
//                   value: _creditSelect,
//                   decoration: const InputDecoration(
//                     labelText: 'Credit Or Trial',
//                     border: OutlineInputBorder(),
//                     contentPadding:
//                         EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   ),
//                   items: ['None', 'Credit', 'Trial']
//                       .map((s) => DropdownMenuItem(value: s, child: Text(s)))
//                       .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _creditSelect = value!;
//                       _credit = value == 'None'
//                           ? 0
//                           : value == 'Credit'
//                               ? 1
//                               : 2;
//                     });
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildDoctorSectionDesktop(Map<String, dynamic>? selectedClient) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Expanded(
//           flex: 1,
//           child: Column(
//             children: [
//               TextFormField(
//                 decoration: const InputDecoration(
//                   labelText: 'Doctor Name',
//                   hintText: 'Doctor Name',
//                   border: OutlineInputBorder(),
//                   prefixText: 'Dr. ',
//                   contentPadding:
//                       EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//                 onChanged: (v) => _doctor = v,
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 children: [
//                   const Text('B2B?', style: TextStyle(fontSize: 14)),
//                   const Spacer(),
//                   Switch(
//                     value: _b2b,
//                     onChanged: (v) {
//                       setState(() => _b2b = v);
//                       if (v) {
//                         _showB2BClientDialog();
//                       } else {
//                         ref.read(_selectedClientPod.notifier).state = null;
//                         setState(() {
//                           _msgSms = true;
//                           _msgWhatsapp = true;
//                           _msgEmail = true;
//                         });
//                       }
//                     },
//                   ),
//                 ],
//               ),
//               if (selectedClient != null) ...[
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   decoration: const InputDecoration(
//                     labelText: 'Selected B2B Client',
//                     border: OutlineInputBorder(),
//                     contentPadding:
//                         EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   ),
//                   readOnly: true,
//                   controller: TextEditingController(
//                     text:
//                         '${selectedClient['first_name']} ${selectedClient['last_name']} (${selectedClient['client_master']['client_name']})',
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 4,
//           child: TextFormField(
//             decoration: const InputDecoration(
//               labelText: 'Free text',
//               hintText: 'Free text',
//               border: OutlineInputBorder(),
//               contentPadding: EdgeInsets.all(12),
//             ),
//             maxLines: 4,
//             onChanged: (v) => _freeText = v,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           flex: 1,
//           child: Column(
//             children: [
//               Container(
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: ListTile(
//                   title:
//                       const Text('VIP Client?', style: TextStyle(fontSize: 14)),
//                   trailing: Switch(
//                     value: _vip,
//                     onChanged: (v) => setState(() => _vip = v),
//                   ),
//                   dense: true,
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 4),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Container(
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: ListTile(
//                   title: const Text('Urgent?', style: TextStyle(fontSize: 14)),
//                   trailing: Switch(
//                     value: _urgent,
//                     onChanged: (v) => setState(() => _urgent = v),
//                   ),
//                   dense: true,
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 4),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               DropdownButtonFormField<String>(
//                 value: _creditSelect,
//                 decoration: const InputDecoration(
//                   labelText: 'Credit Or Trial',
//                   border: OutlineInputBorder(),
//                   contentPadding:
//                       EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//                 items: ['None', 'Credit', 'Trial']
//                     .map((s) => DropdownMenuItem(value: s, child: Text(s)))
//                     .toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _creditSelect = value!;
//                     _credit = value == 'None'
//                         ? 0
//                         : value == 'Credit'
//                             ? 1
//                             : 2;
//                   });
//                 },
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         ElevatedButton(
//           onPressed: _validate,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.blue,
//             padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
//           ),
//           child: const Text('Save',
//               style: TextStyle(color: Colors.white, fontSize: 16)),
//         ),
//         const SizedBox(width: 16),
//         ElevatedButton(
//           onPressed: () => Navigator.of(context).pop(),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.blue,
//             padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
//           ),
//           child: const Text('Close',
//               style: TextStyle(color: Colors.white, fontSize: 16)),
//         ),
//       ],
//     );
//   }

//   Future<void> _selectTime(BuildContext context) async {
//     final TimeOfDay? picked = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.now(),
//     );
//     if (picked != null) {
//       setState(() => _collectionTime = picked);
//     }
//   }

//   Future<void> _pickImage() async {
//     final XFile? image = await _imagePicker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 85,
//     );
//     if (image != null) {
//       setState(() {
//         _prescriptionImage = image;
//         _fileName = image.name;
//         _imageSrc = image.path;
//       });
//     }
//   }

//   void _updateGenderFromSalutation() {
//     if (_salutation == 'Ms' || _salutation == 'Mrs') {
//       _gender = 'Female';
//     } else if (_salutation == 'Mr') {
//       _gender = 'Male';
//     }
//   }

//   void _validate() {
//     if (_formKey.currentState!.validate()) {
//       if (_collectionTime == null) {
//         _showSnackBar('Please select collection time');
//         return;
//       }

//       try {
//         DateTime selectedDate;
//         try {
//           selectedDate = DateFormat('EEEE d MMM yyyy').parse(_collectionDate);
//         } catch (e) {
//           selectedDate = DateFormat('EEEE d MMMM yyyy').parse(_collectionDate);
//         }

//         final today = DateTime.now();
//         final isToday = selectedDate.year == today.year &&
//             selectedDate.month == today.month &&
//             selectedDate.day == today.day;

//         if (isToday && !_validateFutureTime()) {
//           _showSnackBar(
//               'Collection time must be in the future for today\'s appointments');
//           return;
//         }
//       } catch (e) {
//         debugPrint('Error parsing date: $e');
//         _showSnackBar('Invalid date format');
//         return;
//       }

//       _save();
//     }
//   }

//   bool _validateFutureTime() {
//     if (_collectionTime == null) return false;

//     try {
//       final now = DateTime.now();

//       final dtWithTime = DateTime(
//         now.year,
//         now.month,
//         now.day,
//         _collectionTime!.hour,
//         _collectionTime!.minute,
//       );

//       final isAfterNow = dtWithTime.isAfter(now);

//       debugPrint('Selected time: ${_collectionTime!.format(context)}');
//       debugPrint('Current time: ${TimeOfDay.now().format(context)}');
//       debugPrint('Is after now: $isAfterNow');

//       return isAfterNow;
//     } catch (e) {
//       debugPrint('Error validating time: $e');
//       return false;
//     }
//   }

//   Future<void> _save() async {
//     setState(() => _isLoading = true);

//     try {
//       final storage = ref.read(storageServiceProvider);

//       DateTime calendar;
//       try {
//         calendar = DateFormat('EEEE d MMM yyyy').parse(_collectionDate);
//       } catch (e) {
//         calendar = DateFormat('EEEE d MMMM yyyy').parse(_collectionDate);
//       }

//       final idDate = DateFormat('yyyy-MM-dd').format(calendar);
//       final colDate = DateFormat('dd-MM-yyyy').format(calendar);

//       final timeStr =
//           '${_collectionTime!.hour.toString().padLeft(2, '0')}:${_collectionTime!.minute.toString().padLeft(2, '0')}';
//       final appDtTime = '$colDate $timeStr';
//       final sortTime = Util.parseAppTime(appDtTime).millisecondsSinceEpoch;

//       final newId = 'work_order:$idDate:${Util.uuidv4()}';

//       if (_prescriptionImage != null) {
//         _fileLocation =
//             'homecollection/prescriptions/${Util.getTodayStringForFolderCreation()}/$_fileName';

//         debugPrint('Photo to upload: $_fileLocation');
//       }

//       final selectedClient = ref.read(_selectedClientPod);
//       final timeStamp = Util.getTimeStamp();
//       final workOrderCreated =
//           '${Util.gettime()}-${storage.getFromSession('logged_in_emp_name')}- Work Order Created';

//       final doc = {
//         '_id': newId,
//         'name': '$_salutation. ${Util.toTitleCase(_name)}',
//         'age': _age,
//         'gender': _gender,
//         'address': Util.toTitleCase(_address),
//         'email': _email.toLowerCase(),
//         'pincode': _pincode,
//         'mobile': _mobile,
//         'doctor_name': Util.toTitleCase(_doctor),
//         'pro_id': '',
//         'b2b_client_id': selectedClient?['id'] ?? 0,
//         'b2b_client_name': selectedClient != null
//             ? '${selectedClient['first_name']} ${selectedClient['last_name']} (${selectedClient['client_master']['client_name']})'
//             : '',
//         'vip_client': _vip ? 1 : 0,
//         'urgent': _urgent ? 1 : 0,
//         'credit': _credit,
//         'appointment_date': colDate,
//         'appointment_time': timeStr,
//         'pres_photo': _fileLocation,
//         'status': 'unassigned',
//         'server_status': 'waiting',
//         'assigned_to': '',
//         'assigned_id': '',
//         'free_text': _freeText,
//         'process': {
//           'first_step': '',
//           'second_step': '',
//           'third_step': '',
//           'fourth_step': '',
//           'fifth_step': '',
//           'prescription_uploaded_at': '',
//           'proforma_uploaded_at': '',
//         },
//         'settings': {
//           'send_sms': _msgSms ? 1 : 0,
//           'send_whatsapp': _msgWhatsapp ? 1 : 0,
//           'send_email': _msgEmail ? 1 : 0,
//         },
//         'updated_at': timeStamp,
//         'sort_time': sortTime,
//         'manager_id': storage.getFromSession('logged_in_emp_id'),
//         'manager_name': storage.getFromSession('logged_in_emp_name'),
//         'tenant_id': storage.getFromSession('logged_in_tenant_id'),
//         'time_line': [workOrderCreated],
//       };

//       debugPrint('Saving work order: ${jsonEncode(doc)}');

//       final dio =
//           await ref.read(workOrderDbProvider).getServerDB('work_orders');

//       final response = await dio.put(
//         '/$newId',
//         data: doc,
//         options: Options(
//           headers: {
//             'Content-Type': 'application/json',
//           },
//         ),
//       );

//       setState(() => _isLoading = false);

//       if (response.statusCode == 201 ||
//           response.statusCode == 200 ||
//           response.statusCode == 202) {
//         debugPrint('Work order saved successfully: ${response.data}');
//         _showSnackBar('Added Successfully');

//         if (mounted) {
//           Navigator.of(context).pop('refresh');
//         }
//       } else {
//         if (response.statusCode == 409) {
//           throw Exception('Work order with this ID already exists');
//         } else {
//           throw Exception(
//               'Failed to save work order: ${response.statusCode} - ${response.data}');
//         }
//       }
//     } catch (e) {
//       setState(() => _isLoading = false);

//       String errorMessage = 'Error: Please check your internet connection';

//       if (e is DioException) {
//         if (e.response?.statusCode == 401) {
//           errorMessage = 'Authentication failed. Please login again.';
//         } else if (e.response?.statusCode == 409) {
//           errorMessage = 'This work order already exists.';
//         } else if (e.type == DioExceptionType.connectionTimeout) {
//           errorMessage = 'Connection timeout. Please try again.';
//         } else {
//           errorMessage = 'Network error: ${e.message}';
//         }
//       } else {
//         errorMessage = e.toString();
//       }

//       _showSnackBar(errorMessage);
//       debugPrint('Error saving work order: $e');
//     }
//   }

//   void _showSettingsDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Settings'),
//         content: StatefulBuilder(
//           builder: (context, setDialogState) {
//             return Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Padding(
//                   padding: EdgeInsets.only(bottom: 16),
//                   child: Text(
//                     'Do You Want To Send Report, Proforma And Bill To Patient?',
//                     style: TextStyle(fontSize: 14),
//                   ),
//                 ),
//                 SwitchListTile(
//                   title: const Text('SMS'),
//                   value: _msgSms,
//                   onChanged: (v) => setDialogState(() => _msgSms = v),
//                 ),
//                 SwitchListTile(
//                   title: const Text('WhatsApp'),
//                   value: _msgWhatsapp,
//                   onChanged: (v) => setDialogState(() => _msgWhatsapp = v),
//                 ),
//                 SwitchListTile(
//                   title: const Text('Email'),
//                   value: _msgEmail,
//                   onChanged: (v) => setDialogState(() => _msgEmail = v),
//                 ),
//               ],
//             );
//           },
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               setState(() {});
//               Navigator.of(context).pop();
//             },
//             child: const Text('OK'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showB2BClientDialog() async {
//     setState(() => _isLoading = true);

//     try {
//       final dbService = ref.read(postgresServiceProvider);
//       final clients = await dbService.getB2BClients();

//       debugPrint('🔍 B2B clients response: $clients'); // ADD THIS
//       debugPrint('🔍 B2B clients type: ${clients.runtimeType}'); // ADD THIS
//       debugPrint(
//           '🔍 B2B clients length: ${clients is List ? clients.length : "not a list"}');

//       if (clients != null && clients != "Error") {
//         ref.read(_b2bClientsPod.notifier).state =
//             List<Map<String, dynamic>>.from(clients);

//         setState(() => _isLoading = false);

//         if (!mounted) return;

//         showDialog(
//           context: context,
//           builder: (context) => const _B2BClientDialog(),
//         );
//       } else {
//         setState(() {
//           _isLoading = false;
//           _b2b = false;
//         });
//         _showSnackBar('Failed to load B2B clients');
//       }
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         _b2b = false;
//       });
//       _showSnackBar('Error loading B2B clients');
//       debugPrint('Error: $e');
//     }
//   }

//   void _showSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
//     );
//   }
// }

// class _B2BClientDialog extends ConsumerStatefulWidget {
//   const _B2BClientDialog();

//   @override
//   ConsumerState<_B2BClientDialog> createState() => _B2BClientDialogState();
// }

// class _B2BClientDialogState extends ConsumerState<_B2BClientDialog> {
//   String _searchQuery = '';

//   @override
//   Widget build(BuildContext context) {
//     final clients = ref.watch(_b2bClientsPod);
//     final filtered = _searchQuery.isEmpty
//         ? clients
//         : Util.search(clients, _searchQuery.toLowerCase());

//     return Dialog(
//       child: Container(
//         height: 600,
//         width: 800,
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.orange,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: const Text(
//                     'Choose B2B Client',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   icon: const Icon(Icons.close),
//                   onPressed: () => Navigator.of(context).pop(),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Search',
//                 prefixIcon: Icon(Icons.search),
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (v) => setState(() => _searchQuery = v),
//               autofocus: true,
//             ),
//             const SizedBox(height: 16),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade300),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: DataTable(
//                     columnSpacing: 24,
//                     headingRowHeight: 48,
//                     dataRowHeight: 48,
//                     columns: const [
//                       DataColumn(
//                           label: Text('Contact Name',
//                               style: TextStyle(fontWeight: FontWeight.bold))),
//                       DataColumn(
//                           label: Text('Mobile',
//                               style: TextStyle(fontWeight: FontWeight.bold))),
//                       DataColumn(
//                           label: Text('Client Name',
//                               style: TextStyle(fontWeight: FontWeight.bold))),
//                       DataColumn(
//                           label: Text('Client Type',
//                               style: TextStyle(fontWeight: FontWeight.bold))),
//                     ],
//                     rows: filtered.map((client) {
//                       return DataRow(
//                         cells: [
//                           DataCell(Text(
//                               '${client['first_name']} ${client['last_name']}')),
//                           DataCell(Text('${client['mobile']}')),
//                           DataCell(Text(
//                               '${client['client_master']['client_name']}')),
//                           DataCell(Text(
//                               '${client['client_master']['client_type']}')),
//                         ],
//                         onSelectChanged: (_) {
//                           ref.read(_selectedClientPod.notifier).state = client;
//                           Navigator.of(context).pop();
//                         },
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

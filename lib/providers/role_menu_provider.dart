// import '../util.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:anderson_crm_flutter/database/authorize.dart';
// import 'package:flutter/material.dart';
// import '../services/storage_service.dart';

// /* ----------  simple data class  ---------- */
// class MenuItem {
//   final IconData icon;
//   final String label;
//   final String route;
//   const MenuItem(this.icon, this.label, this.route);
// }

// /* ----------  provider  ---------- */
// final roleMenuProvider = FutureProvider<List<MenuItem>>(
//   (ref) async {
//     final storage = ref.read(storageServiceProvider);
//     final role = storage.getFromSession('role_name');
//     final dept = storage.getFromSession('department_name');
//     final raw = await Authorize.getMenus(ref); // List<Map>
//     return raw.map((m) => MenuItem(m['icon'], m['title'], m['link'])).toList();
//   },
// );


// // final roleMenuProvider = FutureProvider<List<MenuItem>>((ref) async {
// //   final raw = await Authorize.getMenus(ref as WidgetRef); // List<Map>
// //   return raw.map((m) => MenuItem(m['icon'], m['title'], m['link'])).toList();
// // });
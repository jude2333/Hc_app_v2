// import 'dart:convert';
// import 'package:anderson_crm_flutter/util.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import '../config/settings.dart';
// // import '../util.dart';
// import '../providers/app_state.dart';
// import 'package:flutter/widgets.dart';
// // import 'package:anderson_crm_flutter/providers/app_state.dart';
// import 'package:anderson_crm_flutter/providers/session_provider.dart';

// class TechnicianDB {
//   static final  _instance = TechnicanDb._internal();
//   factory TechnicaintDB() => _instance;
//   PriceListDB._internal();
//   Dio? _client;
//   String _token = "";

//   Future<void> _setup(WidgetRef ref) async {
//     ref.read(appNotifierProvider.notifier).setStatus('Initializing');

//     if (_token.isEmpty) {
//       _token = Util.getFromSession(ref, "pg_admin");
//     }

//     final options = BaseOptions(
//       baseUrl: Settings.rdbmsDbUrl,
//       connectTimeout: const Duration(seconds: 30),
//       receiveTimeout: const Duration(seconds: 30),
//     );

//     final headers = <String, String>{
//       "Content-Type": "application/json",
//       "Prefer":
//           "count=estimated,resolution=merge-duplicates,return=representation",
//     };

//     if (_token.isNotEmpty) {
//       headers["Authorization"] = "Bearer $_token";
//     }

//     _client = Dio(options)
//       ..options.headers = headers
//       ..options.validateStatus = (status) => status != null && status < 500;

//     ref.read(appNotifierProvider.notifier).setStatus('Ready');
//   }

//   Future<dynamic> refreshToken(WidgetRef ref) async {
//     await _setup(ref);

//     try {
//       final response = await _client!.post("/rpc/refresh_token_v2");

//       if (response.statusCode == 200 && response.data['token'] != null) {
//         _token = response.data['token'];

//         await Util.setSession(ref, "pg_admin", _token);

//         final calendar = DateTime.now().add(const Duration(hours: 10));
//         final expTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(calendar);
//         await Util.setSession(ref, "exp_time", expTime);

//         await _setup(ref);

//         return "OK";
//       }
//     } catch (e) {
//       debugPrint("in refresh token: $e");
//     }

//     return "";
//   }

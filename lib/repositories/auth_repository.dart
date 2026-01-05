// import 'package:dio/dio.dart';
// import '../data/dio_client.dart';

// class AuthRepository {
//   final Dio _dio = DioClient.dio;

//   Future<void> sendOtp(String mobile) async {
//     await _dio.post('/sms/send_otp', data: {'mobile': mobile});
//   }

//   Future<bool> verifyOtp(String mobile, String otp) async {
//     final res = await _dio
//         .post('/sms/check_otp', data: {'mobile': mobile, 'entered_otp': otp});
//     return res.data == 'OTP_MATCH';
//   }

//   // PostgresDB.login() replacement
//   Future<String> backendLogin(String mobile) async {
//     final res = await _dio.post('/auth/login', data: {'mobile': mobile});
//     return res.data.toString();
//   }

//   // Fetch roles
//   Future<List<Map<String, dynamic>>> fetchRoles() async {
//     final res = await _dio.get('/roles');
//     return List<Map<String, dynamic>>.from(res.data);
//   }
// }

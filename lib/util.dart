import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io' show HttpDate, Platform;
import 'package:anderson_crm_flutter/providers/app_state.dart';

class Util {
  static const String shToken =
      'eyJraWQiOiIyMDIxMTExNzA4MjAiLCJhbGciOiJSUzI1NiJ9';

  static String formatDate(String str) {
    try {
      DateTime date = DateTime.parse(str);
      final formattedDate = "${date.day}-${date.month}-${date.year}";
      int hour = date.hour;
      final minute = date.minute;
      final ampm = hour >= 12 ? "pm" : "am";
      hour = hour % 12;
      hour = hour == 0 ? 12 : hour;
      final strTime = "$hour:${minute.toString().padLeft(2, '0')} $ampm";
      return "$formattedDate $strTime";
    } catch (e) {
      try {
        DateTime date = HttpDate.parse(str);
        final formattedDate = "${date.day}-${date.month}-${date.year}";
        int hour = date.hour;
        final minute = date.minute;
        final ampm = hour >= 12 ? "pm" : "am";
        hour = hour % 12;
        hour = hour == 0 ? 12 : hour;
        final strTime = "$hour:${minute.toString().padLeft(2, '0')} $ampm";
        return "$formattedDate $strTime";
      } catch (e2) {
        debugPrint("Error parsing date: $e2");
        return str;
      }
    }
  }

  static int dateDiff(String date) {
    try {
      final date1 = DateTime.parse(date);
      final date2 = DateTime.now();
      final diffDays = date2.difference(date1).inDays.abs();
      debugPrint("diff days: $diffDays");
      return diffDays;
    } catch (e) {
      debugPrint("Util > date_diff: $e");
    }
    return 0;
  }

  static int dateDiff2(String dt1, String dt2) {
    try {
      final date1 = DateTime.parse(dt1);
      final date2 = DateTime.parse(dt2);
      final diffDays = date2.difference(date1).inDays.abs();
      debugPrint("diff days2: $diffDays");
      return diffDays;
    } catch (e) {
      debugPrint("Util > date_diff2: $e");
    }
    return 0;
  }

  static bool dateEquals(String dt1, String dt2) {
    final date1 = DateFormat('dd-MM-yyyy').parse(dt1);
    final date2 = DateFormat('dd-MM-yyyy').parse(dt2);
    return date1.isAtSameMomentAs(date2);
  }

  static String getTodayString() =>
      DateFormat('dd-MM-yyyy').format(DateTime.now());

  static String getTodayWithTime() =>
      DateFormat('dd-MM-yyyy h:mm:ss a').format(DateTime.now());

  static String getDateForId() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  static String getTimeStamp() => DateTime.now().toIso8601String();
  static String getTimeStampWithTimezone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60);

    final sign = offset.isNegative ? '-' : '+';
    final formattedOffset =
        '${sign}${hours.abs().toString().padLeft(2, '0')}:${minutes.abs().toString().padLeft(2, '0')}';

    return '${now.toIso8601String().split('.')[0]}$formattedOffset';
  }

  static DateTime parseAppTime(String dt) =>
      DateFormat('dd-MM-yyyy HH:mm').parse(dt);

  static DateTime parseDate(String dt) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').parse(dt);

  static String formatDateForStorage(DateTime dt) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

  static String addMinutes(DateTime dt, int minutes) {
    final newDt = dt.add(Duration(minutes: minutes));
    return formatDateForStorage(newDt);
  }

  // static void updateTime(Ref ref) async {
  //   final sTime = getFromSession(ref, "server_time");
  //   debugPrint("step 1: $sTime");
  //   final mTime = parseDate(sTime);
  //   debugPrint("step 2: $mTime");
  //   final newTime = addMinutes(mTime, 1);
  //   debugPrint("New Time: $newTime");
  //   setSession(ref, "server_time", newTime);
  // }

  static bool isPassedDate(WidgetRef ref, String dt) {
    if (dt.isEmpty) return false;

    try {
      final format = 'yyyy-MM-dd';
      final orderDate = DateFormat(format).parse(dt);

      final todayStr = ref.read(todayProvider);
      final today = DateFormat('yyyy-MM-dd HH:mm:ss').parse(todayStr);

      final orderDateOnly =
          DateTime(orderDate.year, orderDate.month, orderDate.day);
      final todayDateOnly = DateTime(today.year, today.month, today.day);

      final diff = orderDateOnly.difference(todayDateOnly).inDays;
      return diff < 0;
    } catch (e) {
      debugPrint('Error parsing date in isPassedDate: $e');
      return false;
    }
  }

  // static int getPassedMinutes(WidgetRef ref, String dt) {
  //   final orderDate = parseAppTime(dt);

  //   // final todayStr = ref.read(sessionProvider)["server_time"] ?? "";
  //   final today = parseDate(todayStr);
  //   final diff = orderDate.difference(today).inMinutes;
  //   debugPrint("$diff $dt $todayStr");
  //   return diff;
  // }

  static String getWeekDay([int days = 0]) {
    final calendar = DateTime.now().add(Duration(days: days));
    final weekday = calendar.weekday;
    final dayName = _getWeekdayName(weekday);
    return "$dayName ${calendar.day} ${_getMonthName(calendar.month)} ${calendar.year}";
  }

  static String getWeekDayForDate(String date) {
    final calendar = DateFormat('dd-MM-yyyy').parse(date);
    final weekday = calendar.weekday;
    final dayName = _getWeekdayName(weekday);
    return "$dayName ${calendar.day} ${_getMonthName(calendar.month)} ${calendar.year}";
  }

  static String _getWeekdayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  static String getTodayStringForFolderCreation() =>
      DateFormat('yyyy/MM/dd').format(DateTime.now());

  static String gettime() =>
      DateFormat('MMMM dd, h:mm a').format(DateTime.now());

  static List<Map<String, dynamic>> search(
      List<Map<String, dynamic>> details, String searchStr) {
    final result = <Map<String, dynamic>>[];
    for (final detail in details) {
      if (criteria(detail, searchStr)) {
        result.add(detail);
      }
    }
    debugPrint("searching....$searchStr");
    return result;
  }

  static bool criteria(Map<String, dynamic> item, String str) {
    for (final entry in item.entries) {
      if (entry.key == "_id") continue;
      String strVal;
      if (entry.value is Map || entry.value is List) {
        strVal = jsonEncode(entry.value);
      } else {
        strVal = entry.value.toString();
      }
      if (strVal.toLowerCase().contains(str.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static String getInitials(String firstName, String lastName) {
    if (lastName.isNotEmpty) {
      return "${firstName[0]}${lastName[0]}".toUpperCase();
    } else {
      return "${firstName[0]}${firstName[1]}".toUpperCase();
    }
  }

  static String uuidv4() => const Uuid().v4();

  static String getRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[Random().nextInt(chars.length)])
        .join();
  }

  static String generateOTP() => (100000 + Random().nextInt(900000)).toString();

  static String toTitleCase(String str) {
    if (str.isEmpty) return "";
    return str.split(' ').map((word) {
      if (word.isEmpty) return "";
      return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
    }).join(' ');
  }

  static String formatMoney(double money) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(money);
  }

  static String formatMoneyForPDF(double money) {
    return money.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  static String timeConvert(int num) {
    final hours = num ~/ 60;
    final minutes = num % 60;
    return "$hours hour(s) and $minutes minute(s).";
  }

  static int getNumbers(String str) {
    final res = str.replaceAll(RegExp(r'\D'), '');
    return int.tryParse(res) ?? 0;
  }

  static int parseInt(String value) {
    try {
      final str = value.trim();
      return int.parse(str);
    } catch (e) {
      debugPrint("Error converting to number: $value");
    }
    return 0;
  }

  static bool isNotEmpty(dynamic obj) {
    if (obj is List) return obj.isNotEmpty;
    if (obj is Map) return obj.isNotEmpty;
    if (obj is String) return obj.trim().isNotEmpty;
    return obj != null;
  }

  static String toLowerCase(String str) => str.trim().toLowerCase();

  // static String getFromSession<T extends Object?>(Ref<T> ref, String item) {
  //   return ref.read(storageProvider.notifier).getSession(item);
  // }

  // static Future<void> setSession<T extends Object?>(
  //     Ref<T> ref, String item, dynamic value) async {
  //   await ref.read(storageProvider.notifier).setSession(item, value);
  // }

  // static String getFromLocalStorage<T extends Object?>(
  //     Ref<T> ref, String item) {
  //   return ref.read(storageProvider.notifier).getLocalStorage(item);
  // }

  // static Future<void> setLocalStorage<T extends Object?>(
  //     Ref<T> ref, String item, dynamic value) async {
  //   await ref.read(storageProvider.notifier).setLocalStorage(item, value);
  // }

  // static Future<void> clearSession<T extends Object?>(Ref<T> ref) async {
  //   await ref.read(storageProvider.notifier).clearSession();
  // }

  // static Future<void> clearLocalStorage<T extends Object?>(Ref<T> ref) async {
  //   await ref.read(storageProvider.notifier).clearLocalStorage();
  // }

  // static Future<void> removeFromSession<T extends Object?>(
  //     Ref<T> ref, String key) async {
  //   await ref.read(storageProvider.notifier).removeSession(key);
  // }

  // static Future<void> removeFromLocalStorage<T extends Object?>(
  //     Ref<T> ref, String key) async {
  //   await ref.read(storageProvider.notifier).removeLocalStorage(key);
  // }

  // static Future<bool> isLoggedIn(Ref ref) async {
  //   final loggedIn = getFromSession(ref, "logged_in_emp_id");
  //   debugPrint("is logged in check: $loggedIn");
  //   return loggedIn.isNotEmpty;
  // }

  static Future<bool> isMobile() async {
    if (kIsWeb) {
      final deviceInfo = DeviceInfoPlugin();
      final webInfo = await deviceInfo.webBrowserInfo;
      final userAgent = webInfo.userAgent?.toLowerCase() ?? '';

      final mobileRegex = RegExp(
          r'(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino',
          caseSensitive: false);

      final shortRegex = RegExp(
          r'1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-',
          caseSensitive: false);
      return mobileRegex.hasMatch(userAgent) ||
          (userAgent.length >= 4 &&
              shortRegex.hasMatch(userAgent.substring(0, 4)));
    } else {
      return Platform.isAndroid || Platform.isIOS;
    }
  }

  static String findStatus(List<Map<String, dynamic>> items) {
    try {
      for (final item in items) {
        if (item['Status']?.toString().toLowerCase() == "ready") {
          return item['AccessionNo']?.toString() ?? "";
        }
      }
    } catch (e) {
      debugPrint("Util > find_status > Status Is Empty :$e");
    }
    return "";
  }

  static String checkPatientName(String str) {
    try {
      str = str.toLowerCase().trim();
      if (str.contains(".")) {
        str = str.substring(str.indexOf(".") + 1).trim();
      }
    } catch (e) {
      debugPrint("Util > checkPatientName:$e");
    }
    return str;
  }

  static Function debounce(Function fn, int delay) {
    Timer? timer;
    return () {
      if (timer != null) timer!.cancel();
      timer = Timer(Duration(milliseconds: delay), () {
        fn();
      });
    };
  }

  static List<String> contentRangesplitMulti(String str) {
    const tempChar = "t3mp";

    final re = RegExp(r'(\b|-|/)');
    final replaced = str.replaceAll(re, tempChar);
    return replaced
        .split(tempChar)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String getName(String item) {
    try {
      if (item.contains(" | ")) {
        final parts = item.split(" | ");
        var name = parts[1];
        if (name.contains("/")) {
          name = name.substring(name.lastIndexOf("/") + 1);
        }
        if (name.length > 5) {
          name = "${name.substring(0, 5)}...";
        }
        return name;
      } else {
        if (item.contains("/")) {
          item = item.substring(item.lastIndexOf("/") + 1);
        }
        if (item.length > 10) {
          item = "${item.substring(0, 10)}...";
        }
        return item;
      }
    } catch (e) {
      debugPrint("url is empty here");
    }
    return "";
  }

  static String resolveName(String str) {
    final strArray = str.split(",");
    for (final workStr in strArray) {
      if (workStr.endsWith("_work_orders")) {
        return workStr;
      }
    }
    return "";
  }

  static void callThisAfter(void Function() fn, [int ms = 3000]) =>
      Future.delayed(Duration(milliseconds: ms), fn);

  static String getTodayStore() => getTodayString();

  static void testGeneric<T extends Object?>(Ref<T> ref) {
    debugPrint("Generic ref works!");
  }
}

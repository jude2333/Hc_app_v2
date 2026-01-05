import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/database/db_handler.dart';
import 'package:anderson_crm_flutter/util.dart';
import '../repositories/storage_repository.dart';
import '../database/couch_db.dart';

List<Map<String, dynamic>> _parseAndSortInBackground(
    Map<String, dynamic> params) {
  final String responseBody = params['body'];
  final int criteria = params['criteria'];

  final Map<String, dynamic> data = jsonDecode(responseBody);
  final List<dynamic> rows = data['rows'] ?? [];

  List<Map<String, dynamic>> allItems = [];

  for (var row in rows) {
    if (row['doc'] != null) {
      final doc = row['doc'];

      if (doc['from_name'] != null && doc['to_id'] == criteria) {
        final Map<String, dynamic> cleanDoc = Map<String, dynamic>.from(doc);

        try {
          if (cleanDoc['updated_at'] != null) {
            final DateTime dt =
                DateTime.parse(cleanDoc['updated_at'].toString());

            cleanDoc['updated'] = DateFormat('dd-MMM-yyyy hh:mm a').format(dt);
          } else {
            cleanDoc['updated'] = '';
          }
        } catch (e) {
          cleanDoc['updated'] = cleanDoc['updated_at'].toString();
        }

        allItems.add(cleanDoc);
      }
    }
  }

  allItems.sort((a, b) {
    try {
      DateTime dateA = DateTime.tryParse(a['updated_at']?.toString() ?? '') ??
          DateTime(1970);
      DateTime dateB = DateTime.tryParse(b['updated_at']?.toString() ?? '') ??
          DateTime(1970);
      return dateB.compareTo(dateA);
    } catch (e) {
      return 0;
    }
  });

  return allItems;
}

class NotificationDB {
  final DBHandler _dbHandler;
  final CouchDBClient _couchDB;
  final StorageRepository _storage;

  NotificationDB(this._dbHandler, this._couchDB, this._storage);

  Future<Dio> getServerDB(String name) async {
    String? dbName = _dbHandler.resolveName(name);
    if (dbName == null) return Dio();

    String baseUrl = "https://db-2.andrsn.in/$dbName";
    String username = "webuser";
    String password = "cka0t20iwlxf";

    String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': basicAuth,
        'Content-Type': 'application/json',
      },
      validateStatus: (status) {
        return status! < 500;
      },
    );

    return Dio(options);
  }

  Future<List<Map<String, dynamic>>> list(String status, String today) async {
    try {
      debugPrint("list() today from state: $today");
      DateTime calendar;

      try {
        calendar = DateTime.parse(today);
      } catch (e) {
        debugPrint("Invalid today format '$today', using current date");
        calendar = DateTime.now();
      }

      String endDate = DateFormat('yyyy-MM-dd').format(calendar);
      calendar = calendar.subtract(const Duration(days: 1));
      String startDate = DateFormat('yyyy-MM-dd').format(calendar);

      debugPrint("Notification data > list() > $startDate till $endDate");

      String empIdStr = await _storage.getSessionItem("logged_in_emp_id") ?? "";
      int criteria = int.tryParse(empIdStr) ?? 0;

      String departmentName =
          await _storage.getSessionItem("department_name") ?? "";
      String roleName = await _storage.getSessionItem("role_name") ?? "";

      if (departmentName == "HOME COLLECTION" && roleName == "TECHNICIAN") {
        criteria = int.tryParse(
                await _storage.getSessionItem("logged_in_emp_id") ?? "0") ??
            0;
      }

      Box? localDb = await _dbHandler.getDb("notifications");

      if (localDb != null) {
        List<Map<String, dynamic>> newItems = [];
        List<Map<String, dynamic>> allItems = [];
        Map<dynamic, dynamic> allDocs = localDb.toMap();

        for (var entry in allDocs.entries) {
          String key = entry.key.toString();

          if (key.startsWith("notifications:") &&
              key.compareTo("notifications:$startDate") >= 0 &&
              key.compareTo("notifications:$endDate\ufff0") <= 0) {
            try {
              Map<String, dynamic> doc = Map<String, dynamic>.from(entry.value);

              if (doc['from_name'] != null && doc['to_id'] == criteria) {
                String updated = _safeFormatDate(doc['updated_at']);
                doc['updated'] = updated;

                if (doc['status'] == status) {
                  newItems.add(doc);
                }
                allItems.add(doc);
              }
            } catch (e) {
              debugPrint("Error processing notification entry: $e");
              continue;
            }
          }
        }

        allItems.sort((a, b) {
          try {
            DateTime dateA =
                DateTime.tryParse(a['updated_at']?.toString() ?? '') ??
                    DateTime.now();
            DateTime dateB =
                DateTime.tryParse(b['updated_at']?.toString() ?? '') ??
                    DateTime.now();
            return dateB.compareTo(dateA);
          } catch (e) {
            debugPrint("Error sorting notifications: $e");
            return 0;
          }
        });

        if (allItems.isEmpty && status != "New") {
          allItems.add({
            'from_name': "No Notifications Found.",
            'msg_header': "NA",
            'status': "NA",
            'msg_body': "NA",
            '_id': 'placeholder',
          });
        }

        debugPrint("items length: ${allItems.length}");

        return status == "New" ? newItems : allItems;
      } else {
        debugPrint("Db is null here....notifications db list");
        return [];
      }
    } catch (e) {
      debugPrint("Critical error in notifications list: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listRemoteData(
      String status, String today) async {
    try {
      DateTime calendar;
      try {
        calendar = DateTime.parse(today);
      } catch (e) {
        calendar = DateTime.now();
      }

      String endDate = DateFormat('yyyy-MM-dd').format(calendar);

      int daysBack = status == "New" ? 1 : 30;
      calendar = calendar.subtract(Duration(days: daysBack));
      String startDate = DateFormat('yyyy-MM-dd').format(calendar);

      String empIdStr =
          await _storage.getSessionItem("logged_in_emp_id") ?? "0";
      int criteria = int.tryParse(empIdStr) ?? 0;

      String departmentName =
          await _storage.getSessionItem("department_name") ?? "";
      String roleName = await _storage.getSessionItem("role_name") ?? "";

      if (departmentName == "HOME COLLECTION" && roleName == "TECHNICIAN") {
        criteria = int.tryParse(
                await _storage.getSessionItem("logged_in_emp_id") ?? "0") ??
            0;
      }

      String? name = _dbHandler.resolveName("notifications");
      if (name == null) return [];

      Dio? remoteDb = await _couchDB.getDB(name);
      // if (remoteDb == null) return []; // getDB throws or returns Dio

      debugPrint("📥 Fetching Remote Notifications (Raw String)...");

      Response response = await remoteDb.get(
        "/_all_docs",
        options: Options(responseType: ResponseType.plain),
        queryParameters: {
          "include_docs": true,
          "startkey": jsonEncode("notifications:$startDate"),
          "endkey": jsonEncode("notifications:$endDate\ufff0"),
        },
      );

      List<Map<String, dynamic>> allItems = await compute(
          _parseAndSortInBackground,
          {'body': response.data.toString(), 'criteria': criteria});

      if (status == "New") {
        return allItems.where((doc) => doc['status'] == 'New').toList();
      }

      if (allItems.isEmpty) {
        allItems.add({
          'from_name': "No Notifications Found.",
          'msg_header': "NA",
          'status': "NA",
          'msg_body': "NA",
          '_id': 'placeholder',
        });
      }

      debugPrint("✅ Loaded ${allItems.length} notifications via Isolate.");
      return allItems;
    } catch (e) {
      debugPrint("❌ Error fetching remote notifications: $e");
      return [];
    }
  }

  String _safeFormatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'No date';

      String dateString = dateValue.toString();
      if (dateString.isEmpty) return 'No date';

      DateTime? parsedDate = DateTime.tryParse(dateString);
      if (parsedDate != null) {
        return Util.formatDate(dateString);
      } else {
        debugPrint("Could not parse date: $dateString");
        return dateString;
      }
    } catch (e) {
      debugPrint("Date formatting error: $e");
      return 'Invalid date';
    }
  }

  Future<String> doUpdate(Map<String, dynamic> doc) async {
    Box? localDb = await _dbHandler.getDb("notifications");

    if (localDb != null) {
      try {
        String key = doc['_id'] ??
            'notifications:${DateTime.now().millisecondsSinceEpoch}';

        await localDb.put(key, doc);
        debugPrint("updated doc successfully.");
        return "OK";
      } catch (err) {
        debugPrint("Error updating document: $err");
        return "ERROR:$err";
      }
    } else {
      debugPrint("Db is null here....");
      return "ERROR";
    }
  }

  Future<String> doUpdate2(Map<String, dynamic> doc) async {
    try {
      final remotedb = await getServerDB("notifications");
      // if (remotedb == null) {
      //   debugPrint("Db is null here....");
      //   return "ERROR: Database is null";
      // }

      try {
        final docId = doc['_id'];
        if (docId == null) {
          return "ERROR: Document _id is missing";
        }

        debugPrint("📝 Updating notification: $docId");

        Response getResponse = await remotedb.get('/$docId');
        if (getResponse.statusCode == 200) {
          doc['_rev'] = getResponse.data['_rev'];
          debugPrint("📌 Got current rev: ${doc['_rev']}");
        }

        final response = await remotedb.put(
          '/$docId',
          data: doc,
        );

        debugPrint("📤 Update response status: ${response.statusCode}");

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("✅ Updated notification doc successfully.");
          doc['_rev'] = response.data['rev'];
          debugPrint("📌 New rev: ${doc['_rev']}");

          debugPrint("🔔 Triggering notification refresh...");
          // DBHandler.notificationRefreshBus.add(null); // Removed static access
          // We should rely on DBHandler sync to pick this up, or manually force sync?
          // But this is direct server update.
          // DBHandler sync will eventually pull it.
          // If we want immediate UI update, we should update local DB too?
          // But doUpdate2 seems to be for remote only?

          return "OK";
        } else {
          debugPrint("❌ Update failed with status: ${response.statusCode}");
          return "ERROR: ${response.statusMessage ?? 'Update failed'}";
        }
      } catch (err) {
        debugPrint("❌ Error updating notification document: $err");
        return "ERROR: $err";
      }
    } catch (err) {
      debugPrint("❌ Error getting notification database: $err");
      return "ERROR: $err";
    }
  }

  Future<void> markAsSeen(String docId) async {
    debugPrint('📝 Marking notification $docId as seen.');
    try {
      final doc = await getWithIdRemote(docId);
      if (doc != null) {
        doc['status'] = 'Seen';
        doc['updated_at'] = DateTime.now().toIso8601String();
        await doUpdate2(doc);
        debugPrint('✅ Successfully marked $docId as seen.');
      }
    } catch (e) {
      debugPrint('❌ Failed to mark $docId as seen: $e');
    }
  }

  Future<Map<String, dynamic>?> getWithId(String id) async {
    Box? localBox = await _dbHandler.getDb("notifications");

    if (localBox != null) {
      try {
        dynamic doc = localBox.get(id);
        if (doc != null) {
          return Map<String, dynamic>.from(doc);
        }
      } catch (err) {
        debugPrint("Error fetching notification: $err");
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> getWithIdRemote(String id) async {
    debugPrint("🔍 Remote Fetch data > getWithIdRemote() > $id");

    String? name = _dbHandler.resolveName("notifications");
    if (name == null) {
      debugPrint("❌ Could not resolve notifications database name");
      return null;
    }

    try {
      Dio? remoteDb = await _couchDB.getDB(name);

      Response response = await remoteDb.get("/$id");

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> doc = Map<String, dynamic>.from(response.data);

        if (doc['updated_at'] != null) {
          String updated = _safeFormatDate(doc['updated_at']);
          doc['updated'] = updated;
        }

        debugPrint("✅ Found remote notification: $id");
        return doc;
      } else {
        debugPrint(
            "⚠️ Notification not found: $id (status: ${response.statusCode})");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error fetching remote notification: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listAll(String today) async {
    DateTime calendar = DateFormat('yyyy-MM-dd HH:mm:ss').parse(today);
    String endDate = DateFormat('yyyy-MM-dd').format(calendar);
    calendar = calendar.subtract(const Duration(days: 7));
    String startDate = DateFormat('yyyy-MM-dd').format(calendar);

    debugPrint("All Notification data > list() > $startDate till $endDate");

    int criteria = int.tryParse(
            await _storage.getSessionItem("logged_in_emp_id") ?? "0") ??
        0;
    String departmentName =
        await _storage.getSessionItem("department_name") ?? "";
    String roleName = await _storage.getSessionItem("role_name") ?? "";

    if (departmentName == "HOME COLLECTION" && roleName == "TECHNICIAN") {
      criteria = int.tryParse(
              await _storage.getSessionItem("logged_in_emp_id") ?? "0") ??
          0;
    }

    Box? localBox = await _dbHandler.getDb("notifications");

    if (localBox != null) {
      try {
        List<Map<String, dynamic>> allItems = [];

        List<String> keys = localBox.keys.cast<String>().toList();

        for (String key in keys) {
          if (key.startsWith("notifications:$startDate") &&
              key.compareTo("notifications:$endDate\ufff0") <= 0) {
            dynamic doc = localBox.get(key);
            if (doc != null && doc['from_name'] != null) {
              if (doc['to_id'] == criteria) {
                String updated = Util.formatDate(doc['updated_at']);
                doc['updated'] = updated;
                allItems.add(Map<String, dynamic>.from(doc));
              }
            }
          }
        }

        allItems.sort((a, b) {
          DateTime dateA = DateTime.parse(b['updated_at']);
          DateTime dateB = DateTime.parse(a['updated_at']);
          return dateA.compareTo(dateB);
        });

        if (allItems.isEmpty) {
          allItems.add({
            "from_name": "No Notifications Found.",
            "msg_header": "NA",
            "status": "NA",
            "msg_body": "NA",
          });
        }

        debugPrint("items length: ${allItems.length}");
        return allItems;
      } catch (e) {
        debugPrint("Error fetching all notifications: $e");
      }
    } else {
      debugPrint("Db is null here....notifications db list all");
    }

    return [];
  }
}

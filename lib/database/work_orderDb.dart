import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:anderson_crm_flutter/database/db_handler.dart';
import 'package:anderson_crm_flutter/database/couch_db.dart';
import 'package:anderson_crm_flutter/util.dart';
import 'dart:convert';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

class WorkOrderDB {
  final DBHandler _dbHandler;
  final CouchDBClient _couchDB;

  WorkOrderDB(
    this._dbHandler,
    this._couchDB,
    /*this._storage*/
  );

  Future<Dio> getServerDB(String name) async {
    String? dbName = _dbHandler.resolveName(name);
    if (dbName == null) return Dio();

    String baseUrl = "${Settings.remoteCouchUrl}/$dbName";
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

  Future<Map<String, dynamic>?> getWithIdRemote(String id) async {
    debugPrint("Remote Fetch data > getWithIdRemote() > $id");
    String? name = _dbHandler.resolveName("work_orders");
    if (name == null) return null;

    Dio? remoteDb = await _couchDB.getDB(name);

    try {
      Response response = await remoteDb.get("/$id");

      if (response.data != null) {
        Map<String, dynamic> doc = Map<String, dynamic>.from(response.data);

        if (doc['appointment_date'] != null &&
            doc['appointment_time'] != null) {
          String appDtTime =
              "${doc['appointment_date']} ${doc['appointment_time']}";
          DateTime sortTime = Util.parseAppTime(appDtTime);
          doc['sort_time'] = sortTime.millisecondsSinceEpoch;
        }

        debugPrint("Found remote work order: $id");
        return doc;
      }
    } catch (e) {
      debugPrint("Error fetching remote work order: $e");
      return null;
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> list(String thisDate) async {
    debugPrint("Fetch data > list() > $thisDate");

    Box? localBox = await _dbHandler.getDb("work_orders");
    if (localBox == null) {
      debugPrint("Local box is null, attempting to initialize...");
      await _dbHandler.init();
      localBox = await _dbHandler.getDb("work_orders");
      if (localBox == null) {
        debugPrint("Failed to get local box after init");
        return [];
      }
    }

    List<Map<String, dynamic>> items = [];

    try {
      List<String> keys = localBox.keys.cast<String>().toList();
      debugPrint("Total keys in local box: ${keys.length}");

      String datePrefix = "work_order:$thisDate";

      if (keys.isNotEmpty) {
        debugPrint("Sample keys from box:");
        for (int i = 0; i < min(5, keys.length); i++) {
          debugPrint("  Key[$i]: ${keys[i]}");
        }
      }

      int matchedKeys = 0;
      int validDocs = 0;

      for (String key in keys) {
        if (key.startsWith(datePrefix)) {
          matchedKeys++;

          dynamic docData = localBox.get(key);
          if (docData == null) {
            debugPrint("Warning: Null document for key: $key");
            continue;
          }

          Map<String, dynamic> doc;
          if (docData is Map<String, dynamic>) {
            doc = docData;
          } else if (docData is Map) {
            doc = Map<String, dynamic>.from(docData);
          } else {
            debugPrint(
                "Warning: Invalid document type for key: $key (${docData.runtimeType})");
            continue;
          }

          if (doc['name'] == null) {
            debugPrint("Warning: Document missing 'name' field for key: $key");
          }

          if (!doc.containsKey('_id')) {
            doc['_id'] = key;
          }

          String appointmentDate =
              doc['appointment_date']?.toString() ?? thisDate;
          String appointmentTime =
              doc['appointment_time']?.toString() ?? "00:00";
          String appDateTime = "$appointmentDate $appointmentTime";

          try {
            DateTime sortTime = Util.parseAppTime(appDateTime);
            doc['sort_time'] = sortTime.millisecondsSinceEpoch;
          } catch (e) {
            debugPrint("Error parsing time for $key: $e");

            doc['sort_time'] = DateTime.now().millisecondsSinceEpoch;
          }

          items.add(doc);
          validDocs++;
        }
      }

      debugPrint(
          "Date: $thisDate - Matched keys: $matchedKeys, Valid docs: $validDocs");

      items.sort((a, b) {
        int aTime = a['sort_time'] ?? 0;
        int bTime = b['sort_time'] ?? 0;
        return aTime.compareTo(bTime);
      });

      if (items.isEmpty && localBox.length == 0) {
        debugPrint("No local data found, forcing initial sync...");
        await _dbHandler.forceSync("work_orders");

        keys = localBox.keys.cast<String>().toList();
        for (String key in keys) {
          if (key.startsWith(datePrefix)) {
            dynamic docData = localBox.get(key);
            if (docData != null) {
              Map<String, dynamic> doc = Map<String, dynamic>.from(docData);
              if (!doc.containsKey('_id')) {
                doc['_id'] = key;
              }

              String appointmentDate =
                  doc['appointment_date']?.toString() ?? thisDate;
              String appointmentTime =
                  doc['appointment_time']?.toString() ?? "00:00";
              String appDateTime = "$appointmentDate $appointmentTime";

              try {
                DateTime sortTime = Util.parseAppTime(appDateTime);
                doc['sort_time'] = sortTime.millisecondsSinceEpoch;
                items.add(doc);
              } catch (e) {
                debugPrint("Error parsing time after sync: $e");
              }
            }
          }
        }

        items.sort((a, b) {
          int aTime = a['sort_time'] ?? 0;
          int bTime = b['sort_time'] ?? 0;
          return aTime.compareTo(bTime);
        });
      }

      debugPrint("Returning ${items.length} work orders for $thisDate");
      return items;
    } catch (e, stackTrace) {
      debugPrint("Error in list(): $e");
      debugPrint("Stack trace: $stackTrace");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> smartList(String thisDate) async {
    List<Map<String, dynamic>> localData = await list(thisDate);

    if (localData.isNotEmpty) {
      debugPrint("Using local data: ${localData.length} items");
      return localData;
    }

    debugPrint("No local data, fetching from remote...");
    List<Map<String, dynamic>> remoteData = await listRemoteData(thisDate);

    if (remoteData.isNotEmpty) {
      await _dbHandler.forceSync("work_orders");
    }

    return remoteData;
  }

  Future<List<Map<String, dynamic>>> listRemoteData(String thisDate) async {
    debugPrint("Remote Fetch data > list_remote_data() > $thisDate");
    String? name = _dbHandler.resolveName("work_orders");
    if (name == null) return [];

    Dio? remoteDb = await _couchDB.getDB(name);
    List<Map<String, dynamic>> items = [];

    try {
      Response response = await remoteDb.get(
        "/_all_docs",
        queryParameters: {
          "include_docs": true,
          "startkey": jsonEncode("work_order:$thisDate"),
          "endkey": jsonEncode("work_order:$thisDate\ufff0"),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null && row['doc']['name'] != null) {
            Map<String, dynamic> workDoc =
                Map<String, dynamic>.from(row['doc']);
            String appDtTime =
                "${workDoc['appointment_date']} ${workDoc['appointment_time']}";
            DateTime sortTime = Util.parseAppTime(appDtTime);
            workDoc['sort_time'] = sortTime.millisecondsSinceEpoch;
            items.add(workDoc);
          }
        }

        items.sort(
            (a, b) => (a['sort_time'] as int).compareTo(b['sort_time'] as int));
      }
      debugPrint("Found ${items.length} remote work orders");

      return items;
    } catch (e) {
      debugPrint("Error fetching remote work orders: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> assignedList(String id) async {
    Box? localBox = await _dbHandler.getDb("work_orders");
    List<Map<String, dynamic>> items = [];

    if (localBox != null) {
      try {
        List<String> keys = localBox.keys.cast<String>().toList();

        for (String key in keys) {
          if (key.startsWith("work_order:")) {
            dynamic doc = localBox.get(key);
            if (doc != null && doc['name'] != null) {
              if (doc['assigned_id'] != null &&
                  doc['assigned_id'].toString() == id) {
                Map<String, dynamic> assignedDoc =
                    Map<String, dynamic>.from(doc);
                String appDtTime =
                    "${assignedDoc['appointment_date']} ${assignedDoc['appointment_time']}";
                DateTime sortTime = Util.parseAppTime(appDtTime);
                assignedDoc['sort_time'] = sortTime.millisecondsSinceEpoch;
                items.add(assignedDoc);
              }
            }
          }
        }

        items.sort((a, b) => b['sort_time'].compareTo(a['sort_time']));

        if (items.isEmpty) {
          items.add({
            "name": "No Appointments Found.",
            "age": "NA",
            "gender": "NA",
            "status": "NA",
            "appointment_date": "NA",
          });
        }

        debugPrint("items length: ${items.length}");
        return items;
      } catch (e) {
        debugPrint("Error fetching assigned work orders: $e");
      }
    } else {
      debugPrint("Db is null here....");
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> assignedListRemote(String empId) async {
    debugPrint("Remote Fetch assigned work orders for empId: $empId");

    String? dbName = _dbHandler.resolveName("work_orders");
    if (dbName == null) {
      debugPrint("Could not resolve work_orders database name");
      return [];
    }

    List<Map<String, dynamic>> items = [];

    try {
      Dio dio = await getServerDB("work_orders");

      Response response = await dio.get(
        "/_all_docs",
        queryParameters: {
          "include_docs": true,
          "startkey": jsonEncode("work_order:"),
          "endkey": jsonEncode("work_order:\ufff0"),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        Map<String, dynamic> data = response.data;
        List<dynamic> rows = data['rows'] ?? [];

        debugPrint("Total work orders fetched from remote: ${rows.length}");

        int matchedCount = 0;

        for (var row in rows) {
          if (row['doc'] != null) {
            Map<String, dynamic> doc = Map<String, dynamic>.from(row['doc']);

            String? assignedId = doc['assigned_id']?.toString();

            if (assignedId != null && assignedId == empId) {
              matchedCount++;

              if (!doc.containsKey('_id')) {
                doc['_id'] = row['id'];
              }

              if (doc['name'] != null) {
                String appointmentDate =
                    doc['appointment_date']?.toString() ?? '';
                String appointmentTime =
                    doc['appointment_time']?.toString() ?? '00:00';
                String appDateTime = "$appointmentDate $appointmentTime";

                try {
                  DateTime sortTime = Util.parseAppTime(appDateTime);
                  doc['sort_time'] = sortTime.millisecondsSinceEpoch;
                } catch (e) {
                  debugPrint("Error parsing time for ${doc['_id']}: $e");

                  doc['sort_time'] = DateTime.now().millisecondsSinceEpoch;
                }

                items.add(doc);
              }
            }
          }
        }

        debugPrint("Matched $matchedCount work orders for empId: $empId");

        items.sort((a, b) {
          int aTime = a['sort_time'] ?? 0;
          int bTime = b['sort_time'] ?? 0;
          return bTime.compareTo(aTime);
        });

        if (items.isEmpty) {
          items.add({
            "name": "No Appointments Found.",
            "age": "NA",
            "gender": "NA",
            "status": "NA",
            "appointment_date": "NA",
          });
        }

        debugPrint("Returning ${items.length} assigned work orders");
        return items;
      } else {
        debugPrint("Unexpected status code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching remote assigned work orders: $e");
      if (e is DioException) {
        debugPrint("DioException details: ${e.response?.data}");
        debugPrint("Status code: ${e.response?.statusCode}");
      }

      return [
        {
          "name": "Error loading work orders",
          "age": "NA",
          "gender": "NA",
          "status": "NA",
          "appointment_date": "NA",
        }
      ];
    }
  }

  Future<List<Map<String, dynamic>>> billedList(
      String status, String serverStatus, String today) async {
    DateTime calendar = DateFormat('yyyy-MM-dd HH:mm:ss').parse(today);
    String endDate = DateFormat('yyyy-MM-dd').format(calendar);
    calendar = calendar.subtract(const Duration(days: 7));
    String startDate = DateFormat('yyyy-MM-dd').format(calendar);

    debugPrint("billed data > list() > $startDate till $endDate");

    String? name = _dbHandler.resolveName("work_orders");
    if (name == null) return [];

    Dio? remoteDb = await _couchDB.getDB(name);
    List<Map<String, dynamic>> items = [];

    try {
      Response response = await remoteDb.get(
        "/_all_docs",
        queryParameters: {
          "include_docs": true,
          "startkey": jsonEncode("work_order:$startDate"),
          "endkey": jsonEncode("work_order:$endDate\ufff0"),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null &&
              row['doc']['name'] != null &&
              row['doc']['status'] != null &&
              row['doc']['status'] == status &&
              row['doc']['server_status'] == serverStatus) {
            Map<String, dynamic> workDoc =
                Map<String, dynamic>.from(row['doc']);
            items.add(workDoc);
          }
        }

        if (serverStatus == "Billed") {
          items.sort((a, b) {
            DateTime dateA = DateTime.parse(b['updated_at']);
            DateTime dateB = DateTime.parse(a['updated_at']);
            return dateA.compareTo(dateB);
          });
        } else {
          items.sort((a, b) {
            DateTime dateA = DateTime.parse(a['updated_at']);
            DateTime dateB = DateTime.parse(b['updated_at']);
            return dateA.compareTo(dateB);
          });
        }

        if (items.isEmpty) {
          items.add({
            "name": "No Appointments Found.",
            "age": "NA",
            "gender": "NA",
            "status": "NA",
            "appointment_date": "NA",
          });
        }

        debugPrint("items length: ${items.length}");
        return items;
      }
    } catch (e) {
      debugPrint("Error fetching billed work orders: $e");
    }

    return [];
  }

  Future<String> doUpdate(Map<String, dynamic> doc) async {
    Box? localBox = await _dbHandler.getDb("work_orders");

    if (localBox != null) {
      try {
        doc['_local_modified'] = true;

        await localBox.put(doc['_id'], doc);

        debugPrint("Document marked for sync: ${doc['_id']}");
        return "OK";
      } catch (err) {
        debugPrint("Error updating work order: $err");
        return "ERROR: $err";
      }
    } else {
      debugPrint("Db is null here....");
      return "ERROR";
    }
  }

  Future<String> doUpdate2(Map<String, dynamic> doc) async {
    try {
      final remoteDb = await getServerDB("work_orders");

      // if (localDb == null) {
      //   debugPrint("Db is null here....");
      //   return "ERROR: Database is null";
      // }

      try {
        final docId = doc['_id'];
        if (docId == null) {
          return "ERROR: Document _id is missing";
        }

        final response = await remoteDb.put(
          '/$docId',
          data: doc,
        );

        debugPrint("Response: $response");

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("Updated doc successfully.");
          return "OK";
        } else {
          debugPrint("Update failed with status: ${response.statusCode}");
          return "ERROR: ${response.statusMessage ?? 'Update failed'}";
        }
      } catch (err) {
        debugPrint("Error updating document: $err");
        return "ERROR: $err";
      }
    } catch (err) {
      debugPrint("Error getting database: $err");
      return "ERROR: $err";
    }
  }

  Future<String> doUpdate2Enhanced(Map<String, dynamic> doc) async {
    final remoteDb = await getServerDB("work_orders");

    // if (localDb == null) {
    //   debugPrint("Database is null");
    //   return "ERROR: Database is null";
    // }

    final docId = doc['_id'];
    if (docId == null) {
      debugPrint("Document _id is missing");
      return "ERROR: Document _id is missing";
    }

    try {
      final response = await remoteDb.put(
        '/$docId',
        data: doc,
      );

      debugPrint("Update response: ${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Updated doc successfully.");

        if (response.data != null && response.data['rev'] != null) {
          doc['_rev'] = response.data['rev'];
        }

        return "OK";
      } else {
        final error =
            "Status ${response.statusCode}: ${response.statusMessage}";
        debugPrint("Update failed: $error");
        return "ERROR: $error";
      }
    } on DioException catch (e) {
      final error = e.response?.data ?? e.message ?? 'Unknown error';
      debugPrint("DioException during update: $error");
      return "ERROR: $error";
    } catch (e) {
      debugPrint("Unexpected error during update: $e");
      return "ERROR: $e";
    }
  }

  Future<String> updateAmountDeposit(List<Map<String, dynamic>> docs) async {
    String? name = _dbHandler.resolveName("work_orders");
    if (name == null) return "ERROR: Database name not resolved";

    Dio? remoteDb = await _couchDB.getDB(name);

    if (remoteDb != null) {
      try {
        Response response = await remoteDb.post(
          "/_bulk_docs",
          data: {
            "docs": docs,
          },
        );

        if (response.statusCode == 201 && response.data != null) {
          List<dynamic> results = response.data;
          bool allSuccess = true;

          for (var result in results) {
            if (result['ok'] != true) {
              allSuccess = false;
              debugPrint(
                  "Failed to update document: ${result['id']}, error: ${result['error'] ?? 'Unknown error'}");
            }
          }

          if (allSuccess) {
            debugPrint("${docs.length} documents updated successfully");
            return "OK";
          } else {
            debugPrint("Some documents failed to update");
            return "ERROR: Some documents failed to update";
          }
        } else {
          debugPrint(
              "Failed to update documents, status code: ${response.statusCode}");
          return "ERROR: Failed to update documents";
        }
      } catch (err) {
        debugPrint("Error updating amount deposit: $err");
        return "ERROR: $err";
      }
    } else {
      debugPrint("Database connection is null");
      return "ERROR: Database connection is null";
    }
  }

  Future<List<Map<String, dynamic>>> techAggregateView(
      String id, String thisDate) async {
    debugPrint("TechEngagement > $thisDate");
    String? name = _dbHandler.resolveName("work_orders");
    if (name == null) return [];

    Dio? remoteDb = await _couchDB.getDB(name);
    List<Map<String, dynamic>> items = [];

    try {
      Response response = await remoteDb.get(
        "/_all_docs",
        queryParameters: {
          "include_docs": true,
          "startkey": jsonEncode("work_order:$thisDate"),
          "endkey": jsonEncode("work_order:$thisDate\ufff0"),
        },
      );

      if (response.data['rows'] != null && response.data['rows'] is List) {
        for (var row in response.data['rows']) {
          if (row['doc'] != null &&
              row['doc']['name'] != null &&
              row['doc']['assigned_id'] != null &&
              row['doc']['assigned_id'].toString() == id) {
            Map<String, dynamic> workDoc =
                Map<String, dynamic>.from(row['doc']);
            items.add(workDoc);
          }
        }
      }

      int totalAssigned = 0;
      int totalFinished = 0;
      int totalCancelled = 0;
      int totalPending = 0;

      Map<String, dynamic> techDoc = {
        "total_assigned": 0,
        "total_finished": 0,
        "total_cancelled": 0,
        "total_pending": 0,
        "total_amount": 0,
        "amount_deposit": 0,
        "amount_deposited_status": "",
        "recived_sample": [],
        "assigned_list": [],
      };

      List<String> time = [];
      double total = 0;
      double collected = 0;
      double accepted = 0;

      techDoc["total_amount"] = total;
      techDoc["amount_collected"] = collected;
      techDoc["amount_accepted"] = accepted;

      for (var item in items) {
        if (item['assigned_id'] != null) {
          totalAssigned++;
          techDoc["total_assigned"] = totalAssigned;

          if (item['status'] == "Finished") {
            totalFinished++;
            techDoc["total_finished"] = totalFinished;
          } else if (item['status'] == "cancelled") {
            totalCancelled++;
            techDoc["total_cancelled"] = totalCancelled;
          } else {
            totalPending++;
            techDoc["total_pending"] = totalPending;
          }

          if (item['appointment_time'] != null) {
            time.add(item['appointment_time'].toString());
          }

          if (Util.isNotEmpty(item['amount_received'])) {
            double amount =
                Util.getNumbers(item['amount_received'].toString()).toDouble();
            total += amount;

            if (item['remittance'] != null) {
              collected += amount;
            }

            if (item['accept_remittance'] != null) {
              accepted += amount;
            }
          }

          techDoc["total_amount"] = total;
          techDoc["amount_collected"] = collected;
          techDoc["amount_accepted"] = accepted;

          if (time.isNotEmpty) {
            time.sort();
            techDoc["time_till"] = time.last;
          } else {
            techDoc["time_till"] = "";
          }

          techDoc["recived_sample"] = item['recived_sample'];
          techDoc["assigned_list"] = items;
        }
      }

      return [techDoc];
    } catch (e) {
      debugPrint("Error fetching tech aggregate view: $e");
      return [];
    }
  }

  // Stubs for missing methods

  Future<List<Map<String, dynamic>>> aggregateView(
      String startDate, String endDate,
      [bool local = true]) async {
    // TODO: Implement aggregateView. Original code was lost.
    debugPrint("Warning: aggregateView is not implemented");
    return [];
  }

  Future<List<Map<String, dynamic>>> canceledWorkOrder(String thisDate) async {
    // TODO: Implement canceledWorkOrder. Original code was lost.
    debugPrint("Warning: canceledWorkOrder is not implemented");
    return [];
  }

  Future<List<Map<String, dynamic>>> techEngagements(
      String startDate, String endDate, List<Map<String, dynamic>> technicians,
      [bool local = true]) async {
    // TODO: Implement techEngagements. Original code was lost.
    debugPrint("Warning: techEngagements is not implemented");
    return [];
  }

  Future<List<Map<String, dynamic>>> techSampleVerification(
      String thisDate, List<Map<String, dynamic>> technicians) async {
    // TODO: Implement techSampleVerification. Original code was lost.
    debugPrint("Warning: techSampleVerification is not implemented");
    return [];
  }
}

final workOrderDbProvider = Provider<WorkOrderDB>((ref) {
  final dbHandler = ref.watch(dbHandlerProvider);
  final couchDb = ref.watch(couchDbClientProvider);

  return WorkOrderDB(dbHandler, couchDb /*, storage*/);
});

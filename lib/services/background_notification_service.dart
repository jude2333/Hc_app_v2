import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

class BackgroundNotificationService {
  static const String notificationChannelId = 'bg_notifications_channel';
  static const String notificationChannelName = 'Background Work Order Monitoring';
  static const int foregroundNotificationId = 888;

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the background service configuration.
  /// This should be called in main.dart before runApp.
  static Future<void> initializeService() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final service = FlutterBackgroundService();

    // Configure notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: 'This channel is used for background work order notifications.',
      importance: Importance.low, // low because we don't want it to make sounds for the background service notification itself
      playSound: false,
    );

    // Initialize Local Notifications Plugin
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Default action opens the app
      },
    );

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Home Collection',
        initialNotificationContent: 'Monitoring for new work orders...',
        foregroundServiceNotificationId: foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Start the background notification service if not already running.
  /// Also stores the required CouchDB connection credentials in plain SharedPreferences keys
  /// because the background service runs in a separate isolate and cannot decrypt the main session.
  static Future<void> startService({
    required String token,
    required String dbName,
    required String empId,
  }) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // Request notification permission on Android 13+
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('[BackgroundNotificationService] Error requesting notification permission: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_couch_token', token);
    await prefs.setString('bg_couch_db_name', dbName);
    await prefs.setString('bg_couch_employee_id', empId);

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      debugPrint('[BackgroundNotificationService] Starting background service...');
      await service.startService();
    } else {
      debugPrint('[BackgroundNotificationService] Background service already running, updating config...');
      service.invoke('updateConfig', {
        'token': token,
        'dbName': dbName,
        'empId': empId,
      });
    }
  }

  /// Stop the background notification service and clean up stored credentials.
  static Future<void> stopService() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bg_couch_token');
    await prefs.remove('bg_couch_db_name');
    await prefs.remove('bg_couch_employee_id');

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      debugPrint('[BackgroundNotificationService] Stopping background service...');
      service.invoke('stopService');
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }
}

/// The entry point for the background service running in a separate Dart isolate.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available in the background isolate
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await localNotificationsPlugin.initialize(initializationSettings);

  String? token;
  String? dbName;
  String? empId;

  // Function to load latest configuration values
  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('bg_couch_token');
    dbName = prefs.getString('bg_couch_db_name');
    empId = prefs.getString('bg_couch_employee_id');
    debugPrint('[Background Isolate] Loaded config: token exists=${token != null}, dbName=$dbName, empId=$empId');
  }

  // Load configuration initially
  await loadConfig();

  // Keep track of notification doc IDs we have already alerted on in this run to avoid duplicates
  final Set<String> shownNotificationIds = {};

  service.on('stopService').listen((event) {
    debugPrint('[Background Isolate] stopService event received. Stopping self.');
    service.stopSelf();
  });

  service.on('updateConfig').listen((event) async {
    if (event != null) {
      token = event['token'] as String?;
      dbName = event['dbName'] as String?;
      empId = event['empId'] as String?;
      debugPrint('[Background Isolate] Config updated: dbName=$dbName, empId=$empId');
    }
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  String currentSeq = 'now';
  bool isPolling = true;

  debugPrint('[Background Isolate] Starting CouchDB polling loop...');

  while (isPolling) {
    // If not logged in / configured, sleep and retry/reload config
    if (token == null || dbName == null || empId == null || token!.isEmpty || dbName!.isEmpty || empId!.isEmpty) {
      await Future.delayed(const Duration(seconds: 5));
      await loadConfig();
      continue;
    }

    try {
      final String remoteUrl = "${Settings.remoteCouchUrl}/$dbName";
      final Dio pollingClient = Dio(BaseOptions(
        baseUrl: remoteUrl,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
      ));

      final response = await pollingClient.get(
        '/_changes',
        queryParameters: {
          'feed': 'longpoll',
          'include_docs': 'true',
          'since': currentSeq,
          'timeout': 30000,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['last_seq'] != null) {
          currentSeq = data['last_seq'].toString();
        }

        final List<dynamic> results = data['results'] ?? [];
        if (results.isNotEmpty) {
          debugPrint('[Background Isolate] Received ${results.length} updates');
          for (var row in results) {
            final doc = row['doc'];
            final bool isDeleted = row['deleted'] ?? false;

            if (!isDeleted && doc != null) {
              final String docId = doc['_id']?.toString() ?? "";
              final String toId = doc['to_id']?.toString() ?? "";
              final String status = doc['status']?.toString() ?? "";

              if (toId == empId && status == 'New') {
                if (shownNotificationIds.contains(docId)) {
                  continue; // Skip already notified
                }

                shownNotificationIds.add(docId);

                final String header = doc['msg_header']?.toString() ?? "New Work Order";
                final String body = doc['msg_body']?.toString() ?? "You have been assigned a new work order.";
                
                final int notificationId = doc['created_at'] != null 
                    ? DateTime.tryParse(doc['created_at'].toString())?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch 
                    : DateTime.now().millisecondsSinceEpoch;

                debugPrint('[Background Isolate] Showing system notification for doc $docId: $header - $body');

                // Trigger high importance system notification with sound
                await localNotificationsPlugin.show(
                  notificationId & 0x7FFFFFFF, // Stay in safe 32-bit int bounds
                  header,
                  body,
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'hc_assigned_notifications',
                      'Work Order Assignments',
                      channelDescription: 'Alerts when a new work order is assigned.',
                      importance: Importance.max,
                      priority: Priority.high,
                      playSound: true,
                    ),
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (e is DioException &&
          (e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionTimeout)) {
        // Normal behavior in long polling under unstable connection; just log and retry
        debugPrint('[Background Isolate] Longpoll timeout or connection timeout, retrying...');
      } else {
        debugPrint('[Background Isolate] Error in polling loop: $e');
        // Back off for 10 seconds on regular errors to prevent server spam
        await Future.delayed(const Duration(seconds: 10));
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }
}

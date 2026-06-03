import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class GpsMonitorNotifier extends StateNotifier<bool> {
  Timer? _timer;
  bool _isActive = false;

  GpsMonitorNotifier() : super(true);

  void start() {
    if (_isActive) return;
    _isActive = true;

    _check();

    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
    debugPrint('[GpsMonitor] Started (60s interval)');
  }

  Future<void> _check() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (state != enabled) {
        state = enabled;
        debugPrint(
            '[GpsMonitor] GPS status changed: ${enabled ? "ON" : "OFF"}');
      }
    } catch (e) {
      debugPrint('[GpsMonitor] Check error (non-fatal): $e');
    }
  }

  Future<void> recheck() async => _check();

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    state = true;
    debugPrint('[GpsMonitor] Stopped');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final gpsMonitorProvider =
    StateNotifierProvider<GpsMonitorNotifier, bool>((ref) {
  return GpsMonitorNotifier();
});

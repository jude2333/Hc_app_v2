import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Lightweight GPS status monitor.
/// Checks if GPS is enabled every 60 seconds (only for TECHNICIAN role).
/// Uses a simple bool state — zero battery/CPU impact beyond the check.
class GpsMonitorNotifier extends StateNotifier<bool> {
  Timer? _timer;
  bool _isActive = false;

  /// State: true = GPS is ON, false = GPS is OFF
  GpsMonitorNotifier() : super(true);

  /// Start monitoring (called once after login for technicians)
  void start() {
    if (_isActive) return;
    _isActive = true;

    // Immediate first check
    _check();

    // Then every 60 seconds — lightweight: just one bool syscall
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
    debugPrint('[GpsMonitor] Started (60s interval)');
  }

  Future<void> _check() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (state != enabled) {
        state = enabled;
        debugPrint('[GpsMonitor] GPS status changed: ${enabled ? "ON" : "OFF"}');
      }
    } catch (e) {
      // On web or if check fails, assume GPS is available
      debugPrint('[GpsMonitor] Check error (non-fatal): $e');
    }
  }

  /// Force an immediate re-check (e.g. when user returns from settings)
  Future<void> recheck() async => _check();

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    state = true; // Reset to default
    debugPrint('[GpsMonitor] Stopped');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Provider: true = GPS ON, false = GPS OFF
final gpsMonitorProvider =
    StateNotifierProvider<GpsMonitorNotifier, bool>((ref) {
  return GpsMonitorNotifier();
});

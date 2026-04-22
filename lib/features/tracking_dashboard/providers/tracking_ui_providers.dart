import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tracking_models.dart';

/// Manages the currently selected technician across the dashboard panels
final selectedTechProvider = StateProvider<TechnicianStatus?>((ref) => null);

/// Manages the currently selected date for historical data fetching (Timeline, Analytics, Routes)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Manages the active status filter for the technician list/map ('online', 'offline', 'idle', or null for all)
final statusFilterProvider = StateProvider<String?>((ref) => null);

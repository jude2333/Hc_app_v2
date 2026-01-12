import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page-specific state providers for NotificationsPage

/// Tracks which notification rows are expanded
final expandedRowsProvider = StateProvider<Set<String>>((ref) => {});

/// Tracks which notification is currently being processed (Mark as Seen)
final processingDocIdProvider = StateProvider<String?>((ref) => null);

/// Search query for filtering notifications
final searchQueryProvider = StateProvider<String>((ref) => '');

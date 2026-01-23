import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to hold the list of B2B clients for the dialog
final b2bClientsProvider = StateProvider<List<Map<String, dynamic>>>((_) => []);

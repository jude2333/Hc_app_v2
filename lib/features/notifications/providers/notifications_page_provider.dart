import 'package:flutter_riverpod/flutter_riverpod.dart';

final expandedRowsProvider = StateProvider<Set<String>>((ref) => {});

final processingDocIdProvider = StateProvider<String?>((ref) => null);

final searchQueryProvider = StateProvider<String>((ref) => '');

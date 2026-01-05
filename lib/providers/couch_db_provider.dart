import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/database/couch_db.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/postgres_provider.dart';

final couchDbClientProvider = Provider<CouchDBClient>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  final postgresDb = ref.watch(postgresDbProvider);
  return CouchDBClient(storage, postgresDb);
});

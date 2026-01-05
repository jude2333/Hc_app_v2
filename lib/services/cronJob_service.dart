import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/cron_job.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/postgres_provider.dart';

class CronJobService {
  final Ref ref;

  CronJobService(this.ref);

  void run() {
    CronJob.run(ref);
  }

  void stop() {
    CronJob.stop();
  }

  void restart() {
    stop();
    run();
  }

  Future<void> triggerTokenRefresh() async {
    try {
      final postgresDB = ref.read(postgresDbProvider);
      await postgresDB.refreshToken();
      await ref.read(dbHandlerProvider).init();
    } catch (e) {
      throw 'Error during manual token refresh: $e';
    }
  }

  Future<void> triggerDatabaseInit() async {
    try {
      await ref.read(dbHandlerProvider).init();
    } catch (e) {
      throw 'Error during manual database initialization: $e';
    }
  }
}

final cronJobServiceProvider = Provider<CronJobService>((ref) {
  return CronJobService(ref);
});

import 'package:cron/cron.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/postgres_provider.dart';

class CronJob {
  static Cron? _tokenCron;
  static Cron? _timeCron;

  static void run(Ref ref) {
    try {
      _dbCron(ref);
    } catch (err) {
      debugPrint('Cron job error: $err');
    }
  }

  static void _dbCron(Ref ref) {
    _tokenCron = Cron();
    _tokenCron!.schedule(Schedule.parse('0 */45 * * * *'), () async {
      debugPrint('>>>>>>> calling PostgresDB.refreshToken() <<<<<<<< ');

      final postgresDB = ref.read(postgresDbProvider);
      await postgresDB.refreshToken();

      debugPrint('>>>>>>> calling DBHandler.init() <<<<<<<< ');
      await ref.read(dbHandlerProvider).init();

      // DBHandler.setRef(ref); // No longer needed
    });
    debugPrint('45 min. cloudant cron job created.');
  }

  static void stop() {
    _tokenCron?.close();
    _timeCron?.close();
    _tokenCron = null;
    _timeCron = null;
    debugPrint('Cron jobs stopped.');
  }
}

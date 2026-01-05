import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import './routes/app_router.dart';

// import 'database/db_handler.dart';
// import 'util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive
    await Hive.initFlutter();

    // Initialize encryption (if needed)
    // await Util.initEncryption();

    debugPrint('Anderson CRM Flutter app initialized successfully');
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(
    ProviderScope(
      child: AndersonCRMApp(),
    ),
  );
}

class AndersonCRMApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
        title: 'Anderson CRM',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter);
  }
}

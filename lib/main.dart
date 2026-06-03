import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:hive_flutter/hive_flutter.dart';
import './routes/app_router.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

// import 'database/db_handler.dart';
// import 'util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable browser's native right-click menu on web so Flutter's
  // popup menus (copy/call/sms) aren't blocked by Chrome's overlay.
  // if (kIsWeb) {
  //   BrowserContextMenu.disableContextMenu();
  // }
  try {
    // Initialize Hive
    // await Hive.initFlutter();

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
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Anderson CRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}


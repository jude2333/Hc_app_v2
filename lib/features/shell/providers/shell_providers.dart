import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeProvider = StateProvider<bool>((ref) => false);

final signedInProvider = StateProvider<bool>((ref) => false);

final snackbarMessageProvider = StateProvider<String?>((ref) => null);

final initializingProvider = StateProvider<bool>((ref) => false);

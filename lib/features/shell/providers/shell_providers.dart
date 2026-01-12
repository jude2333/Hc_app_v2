import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide theme mode state
final themeProvider = StateProvider<bool>((ref) => false);

/// Authentication status
final signedInProvider = StateProvider<bool>((ref) => false);

/// Global snackbar message trigger
final snackbarMessageProvider = StateProvider<String?>((ref) => null);

/// Background initialization status
final initializingProvider = StateProvider<bool>((ref) => false);

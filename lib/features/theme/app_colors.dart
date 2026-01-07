import 'package:flutter/material.dart';

/// App-wide color palette
class AppColors {
  // Primary colors
  static const Color primary = Colors.orange;
  static const Color primaryLight =
      Color(0xFFFFF3E0); // orange[100] - stronger light orange
  static const Color primaryDark = Color(0xFFE65100);

  // Secondary/Action colors
  static const Color secondary = Colors.blue;
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.amber;

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFFAFAFA);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;

  // Border/Divider colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Table colors
  static const Color tableRowEven = Colors.white;
  static Color tableRowOdd = Colors.grey[50]!;
  static Color tableRowExpanded = Colors.blue[50]!;
  static Color tableBorder = Colors.grey[200]!;

  // Status colors
  static const Color statusActive = Colors.green;
  static const Color statusInactive = Colors.grey;
  static const Color statusPending = Colors.orange;
}

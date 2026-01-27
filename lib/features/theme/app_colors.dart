import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Colors.orange;
  static const Color primaryLight = Color(0xFFFFF3E0);
  static const Color primaryDark = Color(0xFFE65100);

  static const Color gradientStart = Color(0xFFF57C00);
  static const Color gradientEnd = Color(0xFFFFB74D);

  static const Color secondary = Colors.blue;
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Colors.amber;

  static const Color background = Color(0xFFF5F5F5);
  static const Color backgroundSmoke = Color(0xFFF5F5F5);
  static const Color backgroundLight = Color(0xFFFFF8F4);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFFAFAFA);

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;

  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  static const Color tableRowEven = Colors.white;
  static Color tableRowOdd = Colors.grey[50]!;
  static Color tableRowExpanded = Colors.blue[50]!;
  static Color tableBorder = Colors.grey[200]!;

  static const Color statusActive = Colors.green;
  static const Color statusInactive = Colors.grey;
  static const Color statusPending = Colors.orange;

  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);

  static Color stepInactive = primary.withValues(alpha: 0.1);
  static Color stepActiveGlow = primary.withValues(alpha: 0.4);
}

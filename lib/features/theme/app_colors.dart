import 'package:flutter/material.dart';

/// App-wide color palette
class AppColors {
  // Primary colors
  static const Color primary = Colors.orange;
  static const Color primaryLight =
      Color(0xFFFFF3E0); // orange[100] - stronger light orange
  static const Color primaryDark = Color(0xFFE65100);

  // Gradient colors (for AppBars, backgrounds) - uses standard orange shades
  static const Color gradientStart = Color(0xFFF57C00); // Colors.orange[700]
  static const Color gradientEnd = Color(0xFFFFB74D); // Colors.orange[300]

  // Secondary/Action colors
  static const Color secondary = Colors.blue;
  static const Color success = Color(0xFF10B981); // Emerald green
  static const Color error = Color(0xFFEF4444); // Modern red
  static const Color warning = Colors.amber;

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color backgroundSmoke = Color(0xFFF5F5F5);
  static const Color backgroundLight = Color(0xFFFFF8F4); // Warm off-white
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFFAFAFA);

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B); // Slate-800
  static const Color textSecondary = Color(0xFF64748B); // Slate-500
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

  // Shadow colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.05);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);

  // Step/Progress colors
  static Color stepInactive = primary.withValues(alpha: 0.1);
  static Color stepActiveGlow = primary.withValues(alpha: 0.4);
}

import 'package:flutter/material.dart';

/// App-wide spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

/// App-wide padding presets
class AppPadding {
  // General padding
  static const EdgeInsets none = EdgeInsets.zero;
  static const EdgeInsets xs = EdgeInsets.all(4);
  static const EdgeInsets sm = EdgeInsets.all(8);
  static const EdgeInsets md = EdgeInsets.all(12);
  static const EdgeInsets lg = EdgeInsets.all(16);
  static const EdgeInsets xl = EdgeInsets.all(20);

  // Card/Container padding
  static const EdgeInsets card = EdgeInsets.all(16);
  static const EdgeInsets cardCompact = EdgeInsets.all(12);

  // Table cell padding
  static const EdgeInsets tableCell =
      EdgeInsets.symmetric(horizontal: 16, vertical: 6);
  static const EdgeInsets tableCellCompact =
      EdgeInsets.symmetric(horizontal: 8, vertical: 6);

  // Button padding
  static const EdgeInsets button =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  static const EdgeInsets buttonCompact =
      EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  // Input field padding
  static const EdgeInsets input =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  // Badge/Chip padding
  static const EdgeInsets badge =
      EdgeInsets.symmetric(horizontal: 12, vertical: 6);
}

/// App-wide border radius presets
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 10.0;
  static const double xl = 12.0;
  static const double round = 20.0;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get roundAll => BorderRadius.circular(round);
}

/// App-wide size constants
class AppSizes {
  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;

  // Search field width
  static const double searchFieldWidth = 300.0;

  // Card elevation
  static const double cardElevation = 2.0;
}

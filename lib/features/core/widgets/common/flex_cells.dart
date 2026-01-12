import 'package:flutter/material.dart';

/// Flex-based data cell for table rows (uses Expanded widget).
/// Used in virtual table rows where fixed column widths are needed.
class FlexDataCell extends StatelessWidget {
  final String text;
  final int flex;
  final Color? color;
  final FontWeight? fontWeight;

  const FlexDataCell(
    this.text, {
    super.key,
    required this.flex,
    this.color,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: fontWeight ??
                (color != null ? FontWeight.bold : FontWeight.normal),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Flex-based header cell for table headers (uses Expanded widget).
/// Used in virtual table headers where fixed column widths are needed.
class FlexHeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final Color? color;

  const FlexHeaderCell(
    this.text, {
    super.key,
    this.flex = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color ?? Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

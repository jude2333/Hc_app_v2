import 'package:flutter/material.dart';

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
            color: color ?? Theme.of(context).colorScheme.onSurface,
            fontWeight: fontWeight ??
                (color != null ? FontWeight.bold : FontWeight.normal),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

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
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

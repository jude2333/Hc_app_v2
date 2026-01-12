import 'package:flutter/material.dart';

/// Table header cell widget for work order tables.
class WOTableHeader extends StatelessWidget {
  final String text;

  const WOTableHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Table body cell widget for work order tables.
class WOTableCell extends StatelessWidget {
  final String text;
  final double? fontSize;

  const WOTableCell(this.text, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize),
      ),
    );
  }
}

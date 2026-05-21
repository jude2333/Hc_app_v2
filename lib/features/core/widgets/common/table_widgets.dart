import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/copyable_text.dart';

/// Table header cell widget for work order tables.
class WOTableHeader extends StatelessWidget {
  final String text;

  const WOTableHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
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
/// All cells are copyable. Set [isPhoneNumber] to true for call/sms actions.
class WOTableCell extends StatelessWidget {
  final String text;
  final double? fontSize;
  final bool isPhoneNumber;

  const WOTableCell(this.text,
      {super.key, this.fontSize = 13, this.isPhoneNumber = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: CopyableText(
        text,
        isPhoneNumber: isPhoneNumber,
        style: TextStyle(fontSize: fontSize),
      ),
    );
  }
}

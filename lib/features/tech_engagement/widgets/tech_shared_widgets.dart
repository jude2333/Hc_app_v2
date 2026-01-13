import 'package:flutter/material.dart';

class AggCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const AggCell(this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87)),
      ],
    );
  }
}

class TechHeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;

  const TechHeaderCell(
    this.text, {
    super.key,
    required this.flex,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      );
}

class TechDataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;
  final TextAlign align;

  const TechDataCell(
    this.text, {
    super.key,
    required this.flex,
    this.bold = false,
    this.color,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

class EngagementStatusChip extends StatelessWidget {
  final String status;
  const EngagementStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    if (status == 'Finished') {
      chipColor = Colors.green;
    } else if (status == 'cancelled' || status == 'Cancelled') {
      chipColor = Colors.red;
    } else {
      chipColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        border: Border.all(color: chipColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 12, color: chipColor, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class RemittanceToggle extends StatelessWidget {
  final bool accepted;
  final VoidCallback onToggle;
  const RemittanceToggle(
      {super.key, required this.accepted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: accepted
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          border: Border.all(
            color: accepted ? Colors.green : Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                accepted ? Icons.check_circle : Icons.circle_outlined,
                size: 10,
                color: accepted ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 2),
              Text(
                accepted ? "Y" : "N",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accepted ? Colors.green : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

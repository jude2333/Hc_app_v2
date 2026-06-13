import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'copyable_text.dart';

/// Layout options for NameWithBadges widget.
enum BadgeLayout { row, column }

class NameWithBadges extends StatelessWidget {
  final WorkOrder workOrder;
  final BadgeLayout layout;

  const NameWithBadges({
    super.key,
    required this.workOrder,
    this.layout = BadgeLayout.row,
  });

  List<String> _getFlags() {
    final flags = <String>[];
    if (workOrder.urgent) flags.add('Urgent');
    if (workOrder.vip) flags.add('VIP');
    if (workOrder.credit > 0) {
      flags.add(workOrder.credit == 1 ? 'Credit' : 'Trial');
    }
    if ((workOrder.b2bClientId ?? 0) > 0) flags.add('B2B');
    if (workOrder.cghsClient) flags.add('CGHS');
    return flags;
  }

  List<Widget> _buildBadges(List<String> flags) {
    return flags.map((flag) {
      final isCghs = flag == 'CGHS';
      final color = isCghs ? Colors.blue : Colors.red;
      return Container(
        margin: layout == BadgeLayout.row
            ? const EdgeInsets.only(left: 8)
            : const EdgeInsets.only(top: 4, right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          flag,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final flags = _getFlags();
    final nameWidget = CopyableText(
      workOrder.patientName,
      style: const TextStyle(fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    if (layout == BadgeLayout.row) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : double.infinity,
                ),
                child: nameWidget,
              ),
              ..._buildBadges(flags),
            ],
          );
        },
      );
    }

    // Column layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        nameWidget,
        if (flags.isNotEmpty)
          Wrap(
            children: _buildBadges(flags),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';

/// Layout options for NameWithBadges widget.
enum BadgeLayout { row, column }

/// Displays patient name with badge flags (Urgent, VIP, Credit, Trial, B2B).
/// Used by both Manager and Technician work order pages.
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
    return flags;
  }

  Widget _buildBadge(List<String> flags) {
    if (flags.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: layout == BadgeLayout.row
          ? const EdgeInsets.only(left: 8)
          : const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        flags.join(' '),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flags = _getFlags();
    final nameWidget = Text(
      workOrder.patientName,
      style: const TextStyle(fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    if (layout == BadgeLayout.row) {
      return Row(
        children: [
          Flexible(child: nameWidget),
          if (flags.isNotEmpty) _buildBadge(flags),
        ],
      );
    }

    // Column layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        nameWidget,
        if (flags.isNotEmpty) _buildBadge(flags),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'copyable_text.dart';

/// Layout options for NameWithBadges widget.
enum BadgeLayout { row, column }

class NameWithBadges extends StatelessWidget {
  final WorkOrder? _workOrder;
  final String? _rawName;
  final List<String>? _rawFlags;
  final BadgeLayout layout;
  final TextStyle? nameStyle;

  /// Create from a [WorkOrder] (used by manager views).
  const NameWithBadges({
    super.key,
    required WorkOrder workOrder,
    this.layout = BadgeLayout.row,
    this.nameStyle,
  })  : _workOrder = workOrder,
        _rawName = null,
        _rawFlags = null;

  /// Create from raw name + precomputed flags (used by search views).
  const NameWithBadges.raw({
    super.key,
    required String name,
    required List<String> flags,
    this.layout = BadgeLayout.row,
    this.nameStyle,
  })  : _workOrder = null,
        _rawName = name,
        _rawFlags = flags;

  /// Extract badge flags from a raw CouchDB/PostgreSQL doc map.
  static List<String> extractFlagsFromMap(Map<String, dynamic> data) {
    final flags = <String>[];
    final urgentVal = data['urgent'];
    if (urgentVal == true || urgentVal == 1) flags.add('Urgent');
    final vipVal = data['vip_client'];
    if (vipVal == true || vipVal == 1) flags.add('VIP');
    final credit = data['credit'];
    if (credit == 1) flags.add('Credit');
    if (credit == 2) flags.add('Trial');
    final b2bId = int.tryParse(data['b2b_client_id']?.toString() ?? '0') ?? 0;
    if (b2bId > 0) flags.add('B2B');
    final cghsVal = data['cghs_client'];
    if (cghsVal == true || cghsVal == 1) flags.add('CGHS');
    return flags;
  }

  String get _displayName {
    if (_rawName != null) return _rawName!;
    return _workOrder!.patientName;
  }

  List<String> _getFlags() {
    if (_rawFlags != null) return _rawFlags!;
    final wo = _workOrder!;
    final flags = <String>[];
    if (wo.urgent) flags.add('Urgent');
    if (wo.vip) flags.add('VIP');
    if (wo.credit > 0) {
      flags.add(wo.credit == 1 ? 'Credit' : 'Trial');
    }
    if ((wo.b2bClientId ?? 0) > 0) flags.add('B2B');
    if (wo.cghsClient) flags.add('CGHS');
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
      _displayName,
      style: nameStyle ?? const TextStyle(fontWeight: FontWeight.bold),
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

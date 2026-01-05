import 'dart:convert';

class PriceListItem {
  final String id;
  final String deptId;
  final String deptName;
  final String investId;
  final String investName;
  final String rateCardName;
  final double baseCost;
  final double minCost;
  final double cghsPrice;
  final List<Map<String, dynamic>> history;
  final String? createdAt;
  final String? updatedAt;
  final String? lastUpdatedBy;
  final bool visible;

  const PriceListItem({
    required this.id,
    required this.deptId,
    required this.deptName,
    required this.investId,
    required this.investName,
    this.rateCardName = '',
    this.baseCost = 0,
    this.minCost = 0,
    this.cghsPrice = 0,
    this.history = const [],
    this.createdAt,
    this.updatedAt,
    this.lastUpdatedBy,
    this.visible = true,
  });

  factory PriceListItem.fromRow(Map<String, dynamic> row) {
    List<Map<String, dynamic>> historyList = [];
    if (row['history'] != null && row['history'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(row['history']);
        if (decoded is List) {
          historyList =
              decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (e) {}
    }

    return PriceListItem(
      id: row['id']?.toString() ?? '',
      deptId: row['dept_id']?.toString() ?? '',
      deptName: row['dept_name']?.toString() ?? '',
      investId: row['invest_id']?.toString() ?? '',
      investName: row['invest_name']?.toString() ?? '',
      rateCardName: row['rate_card_name']?.toString() ?? '',
      baseCost: _parseDouble(row['base_cost']),
      minCost: _parseDouble(row['min_cost']),
      cghsPrice: _parseDouble(row['cghs_price']),
      history: historyList,
      createdAt: row['created_at']?.toString(),
      updatedAt: row['updated_at']?.toString(),
      lastUpdatedBy: row['last_updated_by']?.toString(),
      visible: row['visible'] == 1 || row['visible'] == true,
    );
  }

  factory PriceListItem.fromFormData({
    required String deptId,
    required String deptName,
    required String investId,
    required String investName,
    required String baseCost,
    required String minCost,
    required String cghsPrice,
    required String empId,
    required String empName,
    required String empMobile,
    String? rateCardName,
  }) {
    final now = DateTime.now();
    final timestamp = _formatTimestamp(now);
    final idDate = now.toIso8601String().split('T')[0];
    final newId = 'price_list:abp:$idDate:${_generateUuid()}';

    final historyEntry = {
      'action': 'Created',
      'summary': 'New Test Item Created: $investId($investName)',
      'emp_id': empId,
      'emp_name': empName,
      'emp_mobile': empMobile,
      'time_stamp': timestamp,
    };

    return PriceListItem(
      id: newId,
      deptId: deptId,
      deptName: deptName,
      investId: investId,
      investName: investName,
      rateCardName: rateCardName ?? 'ANDERSON BASE PRICE SEPT 2021',
      baseCost: double.tryParse(baseCost) ?? 0,
      minCost: double.tryParse(minCost) ?? 0,
      cghsPrice: double.tryParse(cghsPrice) ?? 0,
      history: [historyEntry],
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      lastUpdatedBy: empName,
      visible: true,
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'dept_id': deptId,
      'dept_name': deptName,
      'invest_id': investId,
      'invest_name': investName,
      'rate_card_name': rateCardName,
      'base_cost': baseCost,
      'min_cost': minCost,
      'cghs_price': cghsPrice,
      'history': jsonEncode(history),
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'last_updated_by': lastUpdatedBy,
      'visible': visible ? 1 : 0,
    };
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      '_id': id,
      'dept_id': deptId,
      'dept_name': deptName,
      'invest_id': investId,
      'invest_name': investName,
      'rate_card_name': rateCardName,
      'base_cost': baseCost.toString(),
      'min_cost': minCost.toString(),
      'cghs_price': cghsPrice.toString(),
      'history': history,
    };
  }

  PriceListItem copyWith({
    String? id,
    String? deptId,
    String? deptName,
    String? investId,
    String? investName,
    String? rateCardName,
    double? baseCost,
    double? minCost,
    double? cghsPrice,
    List<Map<String, dynamic>>? history,
    String? createdAt,
    String? updatedAt,
    String? lastUpdatedBy,
    bool? visible,
  }) {
    return PriceListItem(
      id: id ?? this.id,
      deptId: deptId ?? this.deptId,
      deptName: deptName ?? this.deptName,
      investId: investId ?? this.investId,
      investName: investName ?? this.investName,
      rateCardName: rateCardName ?? this.rateCardName,
      baseCost: baseCost ?? this.baseCost,
      minCost: minCost ?? this.minCost,
      cghsPrice: cghsPrice ?? this.cghsPrice,
      history: history ?? this.history,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      visible: visible ?? this.visible,
    );
  }

  PriceListItem addHistoryEntry({
    required String action,
    required String summary,
    required String empId,
    required String empName,
    required String empMobile,
  }) {
    final newEntry = {
      'action': action,
      'summary': summary,
      'emp_id': empId,
      'emp_name': empName,
      'emp_mobile': empMobile,
      'time_stamp': _formatTimestamp(DateTime.now()),
    };

    final updatedHistory = [newEntry, ...history];

    return copyWith(
      history: updatedHistory,
      updatedAt: DateTime.now().toIso8601String(),
      lastUpdatedBy: empName,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _formatTimestamp(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    return '$day-$month-$year $hour:$minute:$second $ampm';
  }

  static String _generateUuid() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final chars = '0123456789abcdef';
    String uuid = '';

    for (int i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) {
        uuid += '-';
      }
      if (i == 12) {
        uuid += '4';
      } else if (i == 16) {
        uuid += chars[(random % 4) + 8];
      } else {
        uuid += chars[(random + i * 7) % 16];
      }
    }

    return uuid;
  }

  @override
  String toString() =>
      'PriceListItem(id: $id, investName: $investName, baseCost: $baseCost)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceListItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

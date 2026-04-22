import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../models/tech_analytics_models.dart';

// Conditional imports for web vs mobile file saving
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_mobile.dart' as platform_saver;

class ExcelExportService {
  /// Generate and save the analytics Excel workbook (all technicians)
  static Future<void> exportReport(AnalyticsReport report) async {
    final bytes = _generateWorkbook(report);
    final filename =
        'Tech_Analytics_${DateFormat('yyyy-MM-dd').format(report.startDate)}_to_${DateFormat('yyyy-MM-dd').format(report.endDate)}.xlsx';

    await platform_saver.saveExcelFile(bytes, filename);
  }

  /// Generate and save an Excel workbook for a single technician
  static Future<void> exportTechnicianReport(
    TechAnalytics tech,
    AnalyticsReport report,
  ) async {
    final bytes = _generateTechnicianWorkbook(tech, report);
    final safeName = tech.techName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final filename =
        '${safeName}_Analytics_${DateFormat('yyyy-MM-dd').format(report.startDate)}_to_${DateFormat('yyyy-MM-dd').format(report.endDate)}.xlsx';

    await platform_saver.saveExcelFile(bytes, filename);
  }

  /// Build single-technician workbook
  static List<int> _generateTechnicianWorkbook(
    TechAnalytics tech,
    AnalyticsReport report,
  ) {
    final workbook = Workbook();

    _buildTechSummarySheet(workbook, tech, report);
    _buildTechTestSheet(workbook, tech);
    _buildTechOrdersSheet(workbook, tech);

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  // ---- Per-Tech Sheet 1: Summary ----
  static void _buildTechSummarySheet(
    Workbook workbook,
    TechAnalytics tech,
    AnalyticsReport report,
  ) {
    final sheet = workbook.worksheets[0];
    sheet.name = 'Summary';

    // Title
    final titleRange = sheet.getRangeByIndex(1, 1, 1, 4);
    titleRange.merge();
    titleRange.setText('${tech.techName} — Analytics Report');
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.bold = true;

    // Period subtitle
    final periodRange = sheet.getRangeByIndex(2, 1, 2, 4);
    periodRange.merge();
    periodRange.setText(
        '${report.rangeLabel} (${DateFormat('dd MMM yyyy').format(report.startDate)} to ${DateFormat('dd MMM yyyy').format(report.endDate)})');
    periodRange.cellStyle.fontSize = 11;
    periodRange.cellStyle.fontColor = '#666666';

    // KPI rows (label : value)
    final kpis = <String, dynamic>{
      'Total Assigned': tech.totalOrders,
      'Finished': tech.finished,
      'Cancelled': tech.cancelled,
      'Pending': tech.pending,
      '': '', // spacer
      'Total Billed (₹)': tech.totalBilled,
      'Total Received (₹)': tech.totalReceived,
      'Cash Collected (₹)': tech.cashCollected,
      'GPay Collected (₹)': tech.gpayCollected,
      'HC Charges (₹)': tech.hcCharges,
      'Disposable Charges (₹)': tech.disposableCharges,
      'Discount (₹)': tech.totalDiscount,
      ' ': '', // spacer
      'Total Tests': tech.totalTests,
      'Unique Tests': tech.testBreakdown.length,
    };

    int row = 4;
    for (final entry in kpis.entries) {
      if (entry.key.trim().isEmpty) {
        row++;
        continue;
      }

      // Label cell
      final labelCell = sheet.getRangeByIndex(row, 1);
      labelCell.setText(entry.key);
      labelCell.cellStyle.bold = true;
      labelCell.cellStyle.fontSize = 11;

      // Value cell
      final valCell = sheet.getRangeByIndex(row, 2);
      if (entry.value is num) {
        valCell.setNumber((entry.value as num).toDouble());
      } else {
        valCell.setText(entry.value.toString());
      }
      valCell.cellStyle.fontSize = 11;

      // Alternate row shading
      if (row % 2 == 0) {
        labelCell.cellStyle.backColor = '#FFF3E0';
        valCell.cellStyle.backColor = '#FFF3E0';
      }
      row++;
    }

    sheet.autoFitColumn(1);
    sheet.autoFitColumn(2);
  }

  // ---- Per-Tech Sheet 2: Test Breakdown ----
  static void _buildTechTestSheet(Workbook workbook, TechAnalytics tech) {
    final sheet = workbook.worksheets.addWithName('Test Breakdown');

    final headers = ['Test Name', 'Department', 'Count', 'Revenue (₹)'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#3B82F6';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int row = 2;
    double totalRev = 0;
    int totalCount = 0;
    for (final test in tech.testBreakdown) {
      sheet.getRangeByIndex(row, 1).setText(test.investName);
      sheet.getRangeByIndex(row, 2).setText(test.deptName);
      sheet.getRangeByIndex(row, 3).setNumber(test.count.toDouble());
      sheet.getRangeByIndex(row, 4).setNumber(test.totalRevenue);
      totalRev += test.totalRevenue;
      totalCount += test.count;
      row++;
    }

    // Totals row
    final totRow = row;
    sheet.getRangeByIndex(totRow, 1).setText('TOTAL');
    sheet.getRangeByIndex(totRow, 3).setNumber(totalCount.toDouble());
    sheet.getRangeByIndex(totRow, 4).setNumber(totalRev);
    for (int c = 1; c <= 4; c++) {
      final cell = sheet.getRangeByIndex(totRow, c);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#E3F2FD';
    }

    for (int i = 1; i <= 4; i++) {
      sheet.autoFitColumn(i);
    }
  }

  // ---- Per-Tech Sheet 3: Order Details ----
  static void _buildTechOrdersSheet(Workbook workbook, TechAnalytics tech) {
    final sheet = workbook.worksheets.addWithName('Order Details');

    final headers = [
      'Date', 'Time', 'Patient', 'Status', 'Tests',
      'Bill Amt (₹)', 'Received (₹)', 'HC (₹)',
      'Disposable (₹)', 'Payment', 'B2B Client',
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#10B981';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int row = 2;
    for (final order in tech.rawOrders) {
      dynamic doc = order['doc'];
      Map<String, dynamic> docMap = {};
      try {
        if (doc is Map) {
          docMap = Map<String, dynamic>.from(doc);
        } else if (doc is String && doc.isNotEmpty) {
          final decoded = _safeDecode(doc);
          if (decoded is Map) docMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      final testItems = docMap['test_items'] as List? ?? [];
      final testNames =
          testItems.map((t) => t['invest_name']?.toString() ?? '').join(', ');

      sheet.getRangeByIndex(row, 1).setText(order['visit_date']?.toString() ?? '');
      sheet.getRangeByIndex(row, 2).setText(order['visit_time']?.toString() ?? '');
      sheet.getRangeByIndex(row, 3).setText(order['patient_name']?.toString() ?? '');
      sheet.getRangeByIndex(row, 4).setText(order['status']?.toString() ?? '');
      sheet.getRangeByIndex(row, 5).setText(testNames);
      sheet.getRangeByIndex(row, 6).setNumber(
          double.tryParse(docMap['total']?.toString() ?? order['bill_amount']?.toString() ?? '0') ?? 0);
      sheet.getRangeByIndex(row, 7).setNumber(
          double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0);
      sheet.getRangeByIndex(row, 8).setNumber(
          double.tryParse(docMap['hc_charges']?.toString() ?? '0') ?? 0);
      sheet.getRangeByIndex(row, 9).setNumber(
          double.tryParse(docMap['disposable_charges']?.toString() ?? '0') ?? 0);
      sheet.getRangeByIndex(row, 10).setText(docMap['payment_method']?.toString() ?? '');
      sheet.getRangeByIndex(row, 11).setText(docMap['b2b_client_name']?.toString() ?? '');
      row++;
    }

    for (int i = 1; i <= 11; i++) {
      sheet.autoFitColumn(i);
    }
  }

  /// Build the multi-sheet workbook
  static List<int> _generateWorkbook(AnalyticsReport report) {
    final workbook = Workbook();

    _buildSummarySheet(workbook, report);
    _buildTestBreakdownSheet(workbook, report);
    _buildOrderDetailsSheet(workbook, report);

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    return bytes;
  }

  // ---- Sheet 1: Summary ----
  static void _buildSummarySheet(Workbook workbook, AnalyticsReport report) {
    final sheet = workbook.worksheets[0];
    sheet.name = 'Summary';

    // Title row
    final titleRange = sheet.getRangeByIndex(1, 1, 1, 13);
    titleRange.merge();
    titleRange.setText(
        'Technician Analytics — ${report.rangeLabel} (${DateFormat('dd MMM yyyy').format(report.startDate)} to ${DateFormat('dd MMM yyyy').format(report.endDate)})');
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.bold = true;

    // Column headers
    final headers = [
      'Technician',
      'Assigned',
      'Finished',
      'Cancelled',
      'Pending',
      'Billed (₹)',
      'Received (₹)',
      'HC Charges (₹)',
      'Disposable (₹)',
      'Cash (₹)',
      'GPay (₹)',
      'Discount (₹)',
      'Total Tests',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#FF9800'; // Orange header
      cell.cellStyle.fontColor = '#FFFFFF';
      cell.cellStyle.fontSize = 11;
    }

    // Data rows
    int row = 4;
    for (final tech in report.technicians) {
      sheet.getRangeByIndex(row, 1).setText(tech.techName);
      sheet.getRangeByIndex(row, 2).setNumber(tech.totalOrders.toDouble());
      sheet.getRangeByIndex(row, 3).setNumber(tech.finished.toDouble());
      sheet.getRangeByIndex(row, 4).setNumber(tech.cancelled.toDouble());
      sheet.getRangeByIndex(row, 5).setNumber(tech.pending.toDouble());
      sheet.getRangeByIndex(row, 6).setNumber(tech.totalBilled);
      sheet.getRangeByIndex(row, 7).setNumber(tech.totalReceived);
      sheet.getRangeByIndex(row, 8).setNumber(tech.hcCharges);
      sheet.getRangeByIndex(row, 9).setNumber(tech.disposableCharges);
      sheet.getRangeByIndex(row, 10).setNumber(tech.cashCollected);
      sheet.getRangeByIndex(row, 11).setNumber(tech.gpayCollected);
      sheet.getRangeByIndex(row, 12).setNumber(tech.totalDiscount);
      sheet.getRangeByIndex(row, 13).setNumber(tech.totalTests.toDouble());

      // Alternate row shading
      if (row % 2 == 0) {
        for (int c = 1; c <= 13; c++) {
          sheet.getRangeByIndex(row, c).cellStyle.backColor = '#FFF3E0';
        }
      }
      row++;
    }

    // Totals row
    final overall = report.overallTotals;
    final totalRow = row;
    sheet.getRangeByIndex(totalRow, 1).setText('TOTAL');
    sheet.getRangeByIndex(totalRow, 2).setNumber(overall.totalOrders.toDouble());
    sheet.getRangeByIndex(totalRow, 3).setNumber(overall.finished.toDouble());
    sheet.getRangeByIndex(totalRow, 4).setNumber(overall.cancelled.toDouble());
    sheet.getRangeByIndex(totalRow, 5).setNumber(overall.pending.toDouble());
    sheet.getRangeByIndex(totalRow, 6).setNumber(overall.totalBilled);
    sheet.getRangeByIndex(totalRow, 7).setNumber(overall.totalReceived);
    sheet.getRangeByIndex(totalRow, 8).setNumber(overall.hcCharges);
    sheet.getRangeByIndex(totalRow, 9).setNumber(overall.disposableCharges);
    sheet.getRangeByIndex(totalRow, 10).setNumber(overall.cashCollected);
    sheet.getRangeByIndex(totalRow, 11).setNumber(overall.gpayCollected);
    sheet.getRangeByIndex(totalRow, 12).setNumber(overall.totalDiscount);
    sheet.getRangeByIndex(totalRow, 13).setNumber(overall.totalTests.toDouble());

    for (int c = 1; c <= 13; c++) {
      final cell = sheet.getRangeByIndex(totalRow, c);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#E65100';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    // Auto-fit columns
    for (int i = 1; i <= 13; i++) {
      sheet.autoFitColumn(i);
    }
  }

  // ---- Sheet 2: Test Breakdown ----
  static void _buildTestBreakdownSheet(
      Workbook workbook, AnalyticsReport report) {
    final sheet = workbook.worksheets.addWithName('Test Breakdown');

    final headers = ['Technician', 'Test Name', 'Department', 'Count', 'Revenue (₹)'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#3B82F6';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int row = 2;
    for (final tech in report.technicians) {
      for (final test in tech.testBreakdown) {
        sheet.getRangeByIndex(row, 1).setText(tech.techName);
        sheet.getRangeByIndex(row, 2).setText(test.investName);
        sheet.getRangeByIndex(row, 3).setText(test.deptName);
        sheet.getRangeByIndex(row, 4).setNumber(test.count.toDouble());
        sheet.getRangeByIndex(row, 5).setNumber(test.totalRevenue);
        row++;
      }
    }

    for (int i = 1; i <= 5; i++) {
      sheet.autoFitColumn(i);
    }
  }

  // ---- Sheet 3: Order Details ----
  static void _buildOrderDetailsSheet(
      Workbook workbook, AnalyticsReport report) {
    final sheet = workbook.worksheets.addWithName('Order Details');

    final headers = [
      'Date',
      'Time',
      'Patient',
      'Technician',
      'Status',
      'Tests',
      'Bill Amt (₹)',
      'Received (₹)',
      'HC (₹)',
      'Disposable (₹)',
      'Payment',
      'B2B Client',
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#10B981';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    int row = 2;
    for (final tech in report.technicians) {
      for (final order in tech.rawOrders) {
        dynamic doc = order['doc'];
        Map<String, dynamic> docMap = {};
        try {
          if (doc is Map) {
            docMap = Map<String, dynamic>.from(doc);
          } else if (doc is String && doc.isNotEmpty) {
            final decoded = _safeDecode(doc);
            if (decoded is Map) docMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}

        final testItems = docMap['test_items'] as List? ?? [];
        final testNames =
            testItems.map((t) => t['invest_name']?.toString() ?? '').join(', ');

        sheet.getRangeByIndex(row, 1).setText(
            order['visit_date']?.toString() ?? '');
        sheet.getRangeByIndex(row, 2).setText(
            order['visit_time']?.toString() ?? '');
        sheet.getRangeByIndex(row, 3).setText(
            order['patient_name']?.toString() ?? '');
        sheet.getRangeByIndex(row, 4).setText(tech.techName);
        sheet.getRangeByIndex(row, 5).setText(
            order['status']?.toString() ?? '');
        sheet.getRangeByIndex(row, 6).setText(testNames);
        sheet
            .getRangeByIndex(row, 7)
            .setNumber(double.tryParse(
                    docMap['total']?.toString() ?? order['bill_amount']?.toString() ?? '0') ??
                0);
        sheet.getRangeByIndex(row, 8).setNumber(
            double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0);
        sheet.getRangeByIndex(row, 9).setNumber(
            double.tryParse(docMap['hc_charges']?.toString() ?? '0') ?? 0);
        sheet.getRangeByIndex(row, 10).setNumber(
            double.tryParse(
                    docMap['disposable_charges']?.toString() ?? '0') ??
                0);
        sheet.getRangeByIndex(row, 11).setText(
            docMap['payment_method']?.toString() ?? '');
        sheet.getRangeByIndex(row, 12).setText(
            docMap['b2b_client_name']?.toString() ?? '');

        row++;
      }
    }

    for (int i = 1; i <= 12; i++) {
      sheet.autoFitColumn(i);
    }
  }

  static dynamic _safeDecode(String s) {
    try {
      final d = _tryJsonDecode(s);
      if (d is String) return _tryJsonDecode(d);
      return d;
    } catch (_) {
      return {};
    }
  }

  static dynamic _tryJsonDecode(String s) {
    try {
      return s.isEmpty ? {} : (s.startsWith('{') || s.startsWith('[') ? _jsonDecode(s) : {});
    } catch (_) {
      return {};
    }
  }

  static dynamic _jsonDecode(String s) {
    try {
      return s.isEmpty ? {} : Map<String, dynamic>.from(
          (() { try { return jsonDecode(s); } catch (_) { return {}; } })() as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Generates a PDF document from card data and returns file path
  /// Optionally filters by organization type
  Future<String> exportToPdf(
    List<Map<String, dynamic>> cards, {
    String? filterType,
  }) async {
    try {
      // Filter cards if needed
      final filteredCards = filterType != null && filterType != "All"
          ? cards
              .where((c) =>
                  c['organization_type'].toString().toUpperCase() ==
                  filterType.toUpperCase())
              .toList()
          : cards;

      final pdf = pw.Document();

      // Title page
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'SNAPCARD',
                  style: pw.TextStyle(
                    fontSize: 48,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Visiting Card Export Report',
                  style: pw.TextStyle(fontSize: 24),
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Generated on ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Total Cards: ${filteredCards.length}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            );
          },
        ),
      );

      // Data table pages
      if (filteredCards.isNotEmpty) {
        // Split cards into chunks of 20 per page
        const cardsPerPage = 20;
        for (int i = 0; i < filteredCards.length; i += cardsPerPage) {
          final pageCards = filteredCards
              .skip(i)
              .take(cardsPerPage)
              .toList();

          pdf.addPage(
            pw.Page(
              build: (pw.Context context) {
                return pw.Column(
                  children: [
                    pw.Text(
                      'Card Details (${i ~/ cardsPerPage + 1})',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(0.5),
                        1: const pw.FlexColumnWidth(1.5),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(1.5),
                        4: const pw.FlexColumnWidth(1.5),
                        5: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('SL',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Person',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Organization',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Department',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Phone',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Email',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        // Data rows
                        ...pageCards.map((card) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  (card['sl_no'] ?? card['SL No'] ?? '')
                                      .toString(),
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  card['point_person']?.toString() ?? '',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  card['organization_name']?.toString() ?? '',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  card['department']?.toString() ?? '',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  card['contact_number']?.toString() ?? '',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(
                                  card['contact_email']?.toString() ?? '',
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

      // Save PDF to device storage
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'SnapCard_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  /// Generates an Excel (.xlsx) file from card data and returns file path
  /// Optionally filters by organization type
  Future<String> exportToXls(
    List<Map<String, dynamic>> cards, {
    String? filterType,
  }) async {
    try {
      // Filter cards if needed
      final filteredCards = filterType != null && filterType != "All"
          ? cards
              .where((c) =>
                  c['organization_type'].toString().toUpperCase() ==
                  filterType.toUpperCase())
              .toList()
          : cards;

      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add headers
      sheet.appendRow([
        TextCellValue('SL No'),
        TextCellValue('Organization Type'),
        TextCellValue('Organization Name'),
        TextCellValue('Location'),
        TextCellValue('Person'),
        TextCellValue('Department'),
        TextCellValue('Phone'),
        TextCellValue('Email'),
        TextCellValue('Address'),
        TextCellValue('Website'),
      ]);

      // Style header row
      for (int i = 0; i < 10; i++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // Add data rows
      for (int i = 0; i < filteredCards.length; i++) {
        final card = filteredCards[i];
        final slNoVal = card['sl_no'] ?? card['SL No'] ?? '';
        final parsedSl = int.tryParse(slNoVal.toString());

        sheet.appendRow([
          parsedSl != null ? IntCellValue(parsedSl) : TextCellValue(slNoVal.toString()),
          TextCellValue(card['organization_type']?.toString() ?? ''),
          TextCellValue(card['organization_name']?.toString() ?? ''),
          TextCellValue(card['location']?.toString() ?? ''),
          TextCellValue(card['point_person']?.toString() ?? ''),
          TextCellValue(card['department']?.toString() ?? ''),
          TextCellValue(card['contact_number']?.toString() ?? ''),
          TextCellValue(card['contact_email']?.toString() ?? ''),
          TextCellValue(card['address']?.toString() ?? ''),
          TextCellValue(card['url']?.toString() ?? ''),
        ]);
      }

      // Auto-size columns
      for (int i = 0; i < 10; i++) {
        sheet.setColumnWidth(i, 20.0);
      }

      // Save Excel file to device storage
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'SnapCard_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);

      return file.path;
    } catch (e) {
      throw Exception('Failed to generate Excel file: $e');
    }
  }

  /// Generates a CSV file from card data and returns file path
  /// Optionally filters by organization type
  Future<String> exportToCsv(
    List<Map<String, dynamic>> cards, {
    String? filterType,
  }) async {
    try {
      // Filter cards if needed
      final filteredCards = filterType != null && filterType != "All"
          ? cards
              .where((c) =>
                  c['organization_type'].toString().toUpperCase() ==
                  filterType.toUpperCase())
              .toList()
          : cards;

      // Build CSV content
      StringBuffer csv = StringBuffer();

      // Add headers
      csv.writeln(
          'SL No,Organization Type,Organization Name,Location,Person,Department,Phone,Email,Address,Website');

      // Add data rows
      for (var card in filteredCards) {
        final slNo = card['sl_no'] ?? card['SL No'] ?? '';
        final orgType = _escapeCsv(card['organization_type']?.toString() ?? '');
        final orgName = _escapeCsv(card['organization_name']?.toString() ?? '');
        final location = _escapeCsv(card['location']?.toString() ?? '');
        final person = _escapeCsv(card['point_person']?.toString() ?? '');
        final dept = _escapeCsv(card['department']?.toString() ?? '');
        final phone = _escapeCsv(card['contact_number']?.toString() ?? '');
        final email = _escapeCsv(card['contact_email']?.toString() ?? '');
        final address = _escapeCsv(card['address']?.toString() ?? '');
        final url = _escapeCsv(card['url']?.toString() ?? '');

        csv.writeln(
            '$slNo,$orgType,$orgName,$location,$person,$dept,$phone,$email,$address,$url');
      }

      // Save CSV file to device storage
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'SnapCard_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());

      return file.path;
    } catch (e) {
      throw Exception('Failed to generate CSV file: $e');
    }
  }

  /// Shares file via system share sheet
  Future<void> shareFile(String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Check out my SnapCard export!',
      );
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  /// Escape CSV fields that contain special characters
  String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}

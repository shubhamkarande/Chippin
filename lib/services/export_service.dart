import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/balance.dart';

/// Export service for generating PDF and CSV reports.
class ExportService {
  final _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy');

  /// Export expenses to PDF
  Future<File> exportToPdf({
    required Group group,
    required List<Expense> expenses,
    required List<Balance> balances,
    required List<SimplifiedDebt> debts,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(group),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          _buildSummarySection(group, expenses),
          pw.SizedBox(height: 20),
          _buildBalancesSection(balances),
          pw.SizedBox(height: 20),
          _buildDebtsSection(debts),
          pw.SizedBox(height: 20),
          _buildExpensesTable(expenses),
        ],
      ),
    );

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/chippin_${group.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  pw.Widget _buildPdfHeader(Group group) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Chippin',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#6366F1'),
              ),
            ),
            pw.Text(
              _dateFormat.format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          group.name,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _buildSummarySection(Group group, List<Expense> expenses) {
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final avgExpense = expenses.isEmpty ? 0.0 : total / expenses.length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F1F5F9'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total Expenses', _currencyFormat.format(total)),
              _buildSummaryItem('Number of Expenses', expenses.length.toString()),
              _buildSummaryItem('Average', _currencyFormat.format(avgExpense)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildBalancesSection(List<Balance> balances) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Member Balances',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        ...balances.map((b) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(b.displayName, style: const pw.TextStyle(fontSize: 12)),
              pw.Text(
                b.formattedBalance,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: b.isOwed
                      ? PdfColor.fromHex('#10B981')
                      : b.owesOthers
                          ? PdfColor.fromHex('#EF4444')
                          : PdfColors.grey600,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  pw.Widget _buildDebtsSection(List<SimplifiedDebt> debts) {
    if (debts.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#D1FAE5'),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          '✓ All settled up!',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#065F46'),
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Settlement Plan',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        ...debts.map((d) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.indigo,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: d.fromUserName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      const pw.TextSpan(text: ' pays '),
                      pw.TextSpan(
                        text: d.toUserName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      const pw.TextSpan(text: ' '),
                      pw.TextSpan(
                        text: _currencyFormat.format(d.amount),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#6366F1'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  pw.Widget _buildExpensesTable(List<Expense> expenses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Expense Details',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Description', isHeader: true),
                _buildTableCell('Paid By', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
              ],
            ),
            ...expenses.map((e) => pw.TableRow(
              children: [
                _buildTableCell(_dateFormat.format(e.expenseDate)),
                _buildTableCell(e.description),
                _buildTableCell(e.paidBy?.displayName ?? 'Unknown'),
                _buildTableCell(_currencyFormat.format(e.amount)),
              ],
            )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  /// Export expenses to CSV
  Future<File> exportToCsv({
    required Group group,
    required List<Expense> expenses,
  }) async {
    final rows = <List<dynamic>>[
      // Header row
      ['Date', 'Description', 'Amount', 'Currency', 'Paid By', 'Category', 'Split Type', 'Notes'],
      // Data rows
      ...expenses.map((e) => [
        _dateFormat.format(e.expenseDate),
        e.description,
        e.amount.toStringAsFixed(2),
        e.currency,
        e.paidBy?.displayName ?? 'Unknown',
        e.category?.name ?? 'Other',
        e.splitType.displayName,
        e.notes,
      ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/chippin_${group.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);

    return file;
  }

  /// Share file
  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Chippin Expense Report',
    );
  }

  /// Print PDF
  Future<void> printPdf(File file) async {
    await Printing.layoutPdf(
      onLayout: (format) async => await file.readAsBytes(),
    );
  }

  /// Preview PDF
  Future<void> previewPdf(BuildContext context, File file) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('PDF Preview'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => shareFile(file),
              ),
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () => printPdf(file),
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) async => await file.readAsBytes(),
            allowPrinting: true,
            allowSharing: true,
          ),
        ),
      ),
    );
  }
}

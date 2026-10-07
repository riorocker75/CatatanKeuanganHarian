import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import '../models/transaction_model.dart';
import 'package:intl/intl.dart';

class ExportService {
  Future<void> exportToPDF(List<TransactionModel> transactions, {String? title}) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (var t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title ?? 'Laporan Keuangan',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                  ),
                  pw.Text(
                    'Hal. ${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.teal400),
              pw.SizedBox(height: 12),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pemasukan', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(currencyFormat.format(totalIncome),
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pengeluaran', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(currencyFormat.format(totalExpense),
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Selisih / Saldo', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text(currencyFormat.format(totalIncome - totalExpense),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: (totalIncome >= totalExpense) ? PdfColors.blue700 : PdfColors.orange700,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Tanggal', 'Judul', 'Kategori', 'Sumber', 'Tipe', 'Jumlah'],
              data: transactions.map((t) => [
                DateFormat('dd/MM/yyyy HH:mm').format(t.date),
                t.title,
                t.category,
                t.walletName ?? 'Cash',
                t.type == TransactionType.income ? 'Masuk' : 'Keluar',
                currencyFormat.format(t.amount),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final fileName = 'laporan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: title ?? 'Laporan Keuangan');
  }

  Future<void> exportToCSV(List<TransactionModel> transactions, {String? title}) async {
    final List<List<dynamic>> rows = [];
    
    rows.add(['Tanggal', 'Judul', 'Deskripsi', 'Kategori', 'Dompet', 'Tipe', 'Jumlah']);
    
    for (var t in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm:ss').format(t.date),
        t.title,
        t.description,
        t.category,
        t.walletName ?? 'Cash',
        t.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
        t.amount,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final output = await getTemporaryDirectory();
    final fileName = 'transaksi_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${output.path}/$fileName');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: title ?? 'Data Transaksi CSV');
  }
}
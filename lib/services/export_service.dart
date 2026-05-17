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
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title ?? 'Laporan Keuangan',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Pemasukan:', style: pw.TextStyle(fontSize: 12)),
                      pw.Text(currencyFormat.format(totalIncome), 
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.green)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Pengeluaran:', style: pw.TextStyle(fontSize: 12)),
                      pw.Text(currencyFormat.format(totalExpense),
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.red)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Tanggal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Judul', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Kategori', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Tipe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Jumlah', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...transactions.map((t) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(DateFormat('dd/MM/yyyy').format(t.date))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(t.title)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(t.category)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(t.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran')),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          currencyFormat.format(t.amount),
                          style: pw.TextStyle(
                            color: t.type == TransactionType.income ? PdfColors.green : PdfColors.red,
                          ),
                        ),
                      ),
                    ],
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/laporan_keuangan.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan Keuangan');
  }

  Future<void> exportToCSV(List<TransactionModel> transactions) async {
    final List<List<dynamic>> rows = [];
    
    rows.add(['Tanggal', 'Judul', 'Deskripsi', 'Kategori', 'Tipe', 'Jumlah']);
    
    for (var t in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd HH:mm:ss').format(t.date),
        t.title,
        t.description,
        t.category,
        t.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran',
        t.amount,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/transaksi.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Data Transaksi CSV');
  }
}
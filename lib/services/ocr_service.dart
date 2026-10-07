import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_model.dart';
import '../utils/constants.dart';

class ParsedReceiptData {
  final String? merchantName;
  final double? totalAmount;
  final DateTime? date;
  final String? suggestedCategory;
  final TransactionType type;
  final String rawText;

  const ParsedReceiptData({
    this.merchantName,
    this.totalAmount,
    this.date,
    this.suggestedCategory,
    this.type = TransactionType.expense,
    required this.rawText,
  });
}

class OcrService {
  final ImagePicker _picker = ImagePicker();

  /// Scan receipt from Camera or Gallery, process text in-memory with Google ML Kit,
  /// and automatically delete temporary image file (Zero-Storage).
  Future<ParsedReceiptData?> scanReceipt({ImageSource source = ImageSource.camera}) async {
    XFile? imageFile;
    TextRecognizer? textRecognizer;

    try {
      imageFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (imageFile == null) return null;

      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      final parsed = _parseReceiptText(recognizedText.text);
      return parsed;
    } catch (e) {
      return null;
    } finally {
      // Clean up recognizer resources
      try {
        await textRecognizer?.close();
      } catch (_) {}

      // Zero-Storage: Delete temporary photo file immediately
      if (imageFile != null) {
        try {
          final file = File(imageFile.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  ParsedReceiptData _parseReceiptText(String fullText) {
    if (fullText.trim().isEmpty) {
      return const ParsedReceiptData(rawText: '');
    }

    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? merchant;
    double? totalAmount;
    DateTime? date;
    String? category;

    // 1. Detect Merchant Name (Usually within first 4 lines)
    for (int i = 0; i < lines.length && i < 4; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      // Skip date-like lines, address labels, or purely numeric lines
      if (RegExp(r'^\d+$').hasMatch(line) ||
          lower.contains('jl.') ||
          lower.contains('jalan') ||
          lower.contains('telp') ||
          lower.contains('tanggal') ||
          lower.contains('receipt') ||
          lower.contains('struk')) {
        continue;
      }
      if (line.length >= 3 && line.length <= 40) {
        merchant = line;
        break;
      }
    }

    // 2. Detect Total Amount (Search for lines with Total, Jumlah, Tagihan, Rp, Grand Total)
    final candidateAmounts = <double>[];

    final totalKeywords = [
      'grand total',
      'total bayar',
      'total tagihan',
      'total belanja',
      'total akhir',
      'total',
      'jumlah bayar',
      'jumlah',
      'tagihan',
      'tunai',
      'cash',
      'bayar',
      'netto',
      'subtotal',
    ];

    for (var line in lines) {
      final lower = line.toLowerCase();
      for (var kw in totalKeywords) {
        if (lower.contains(kw)) {
          final amount = _extractHighestNumber(line);
          if (amount != null && amount > 0) {
            candidateAmounts.add(amount);
          }
        }
      }
    }

    // If no keyword match found, check lines with "Rp" or valid currency format
    if (candidateAmounts.isEmpty) {
      for (var line in lines) {
        if (line.toUpperCase().contains('RP') || line.contains('.')) {
          final amount = _extractHighestNumber(line);
          if (amount != null && amount >= 1000) {
            candidateAmounts.add(amount);
          }
        }
      }
    }

    if (candidateAmounts.isNotEmpty) {
      // Prioritize the largest sensible amount from total candidates
      candidateAmounts.sort((a, b) => b.compareTo(a));
      totalAmount = candidateAmounts.first;
    }

    // 3. Detect Date
    final dateRegexes = [
      RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})'),
      RegExp(r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2})'),
      RegExp(r'(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})'),
    ];

    for (var line in lines) {
      for (var reg in dateRegexes) {
        final match = reg.firstMatch(line);
        if (match != null) {
          try {
            final p1 = int.parse(match.group(1)!);
            final p2 = int.parse(match.group(2)!);
            final p3 = int.parse(match.group(3)!);

            if (p3 >= 2000) {
              // format dd/mm/yyyy
              date = DateTime(p3, p2, p1);
            } else if (p1 >= 2000) {
              // format yyyy/mm/dd
              date = DateTime(p1, p2, p3);
            } else if (p3 < 100) {
              // format dd/mm/yy
              date = DateTime(2000 + p3, p2, p1);
            }
            if (date != null) break;
          } catch (_) {}
        }
      }
      if (date != null) break;
    }

    // 4. Suggest Category from Merchant or Receipt Text
    final lowerFull = fullText.toLowerCase();
    if (lowerFull.contains('resto') ||
        lowerFull.contains('cafe') ||
        lowerFull.contains('coffee') ||
        lowerFull.contains('kopi') ||
        lowerFull.contains('makan') ||
        lowerFull.contains('food') ||
        lowerFull.contains('warung') ||
        lowerFull.contains('dapur') ||
        lowerFull.contains('bakso') ||
        lowerFull.contains('mie') ||
        lowerFull.contains('nasi')) {
      category = 'Makanan';
    } else if (lowerFull.contains('spbu') ||
        lowerFull.contains('pertamina') ||
        lowerFull.contains('shell') ||
        lowerFull.contains('bensin') ||
        lowerFull.contains('pertalite') ||
        lowerFull.contains('pertamax') ||
        lowerFull.contains('solar') ||
        lowerFull.contains('grab') ||
        lowerFull.contains('gojek') ||
        lowerFull.contains('parkir') ||
        lowerFull.contains('tol')) {
      category = 'Transportasi';
    } else if (lowerFull.contains('mart') ||
        lowerFull.contains('alfamart') ||
        lowerFull.contains('indomaret') ||
        lowerFull.contains('supermarket') ||
        lowerFull.contains('swalayan') ||
        lowerFull.contains('toko') ||
        lowerFull.contains('mall') ||
        lowerFull.contains('fashion') ||
        lowerFull.contains('baju')) {
      category = 'Belanja';
    } else if (lowerFull.contains('apotek') ||
        lowerFull.contains('kimia farma') ||
        lowerFull.contains('k24') ||
        lowerFull.contains('obat') ||
        lowerFull.contains('klinik') ||
        lowerFull.contains('hospital') ||
        lowerFull.contains('dokter')) {
      category = 'Kesehatan';
    } else if (lowerFull.contains('pln') ||
        lowerFull.contains('pdam') ||
        lowerFull.contains('listrik') ||
        lowerFull.contains('wifi') ||
        lowerFull.contains('indihome') ||
        lowerFull.contains('pulsa') ||
        lowerFull.contains('bpjs')) {
      category = 'Tagihan';
    } else {
      category = AppConstants.defaultExpenseCategories.first;
    }

    return ParsedReceiptData(
      merchantName: merchant,
      totalAmount: totalAmount,
      date: date ?? DateTime.now(),
      suggestedCategory: category,
      type: TransactionType.expense,
      rawText: fullText,
    );
  }

  double? _extractHighestNumber(String line) {
    // Clean string keeping digits, dots, commas
    final clean = line.replaceAll(RegExp(r'[^\d.,]'), ' ');
    final parts = clean.split(' ').where((p) => p.trim().isNotEmpty);

    double? maxNum;

    for (var part in parts) {
      // Remove trailing punctuation
      var sanitized = part.replaceAll(RegExp(r'^[.,]+|[.,]+$'), '');
      if (sanitized.isEmpty) continue;

      // Check standard Indonesian format: 150.000,00 or 150.000 or 150000
      if (sanitized.contains('.') && !sanitized.contains(',')) {
        // e.g. 150.000
        sanitized = sanitized.replaceAll('.', '');
      } else if (sanitized.contains(',') && sanitized.contains('.')) {
        // e.g. 150.000,00
        sanitized = sanitized.replaceAll('.', '').replaceAll(',', '.');
      } else if (sanitized.contains(',')) {
        // e.g. 150000,00 or 150,000
        if (sanitized.split(',').last.length == 2) {
          sanitized = sanitized.replaceAll(',', '.');
        } else {
          sanitized = sanitized.replaceAll(',', '');
        }
      }

      final val = double.tryParse(sanitized);
      if (val != null && val > 0 && val < 1000000000) {
        if (maxNum == null || val > maxNum) {
          maxNum = val;
        }
      }
    }

    return maxNum;
  }
}

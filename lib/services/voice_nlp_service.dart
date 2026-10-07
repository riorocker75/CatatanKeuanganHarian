import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../utils/constants.dart';

class ParsedVoiceData {
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String? walletId;
  final String? walletName;
  final String rawSpeech;

  const ParsedVoiceData({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.walletId,
    this.walletName,
    required this.rawSpeech,
  });
}

class VoiceNlpService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (err) {},
        onStatus: (status) {},
      );
      return _isInitialized;
    } catch (_) {
      return false;
    }
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(String status) onStatus,
  }) async {
    final hasInit = await initialize();
    if (!hasInit) return;

    // Check available locales for Indonesian
    String targetLocaleId = 'id_ID';
    try {
      final locales = await _speech.locales();
      final hasIndonesian = locales.any((l) => l.localeId.startsWith('id'));
      if (!hasIndonesian && locales.isNotEmpty) {
        targetLocaleId = locales.first.localeId;
      }
    } catch (_) {}

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        localeId: targetLocaleId,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  ParsedVoiceData parseVoiceText(
    String speechText, {
    List<String>? expenseCategories,
    List<String>? incomeCategories,
    List<WalletModel>? userWallets,
  }) {
    final lower = speechText.toLowerCase().trim();
    if (lower.isEmpty) {
      return ParsedVoiceData(
        title: 'Transaksi Baru',
        amount: 0,
        type: TransactionType.expense,
        category: AppConstants.defaultExpenseCategories.first,
        rawSpeech: speechText,
      );
    }

    // 1. Determine Transaction Type
    TransactionType type = TransactionType.expense;
    final incomeKeywords = [
      'gaji',
      'bonus',
      'dapat',
      'terima',
      'masuk',
      'penjualan',
      'untung',
      'jual',
      'pemasukan',
      'transfer masuk',
      'cair',
      'hadiah',
      'thr',
    ];

    for (var kw in incomeKeywords) {
      if (lower.contains(kw)) {
        type = TransactionType.income;
        break;
      }
    }

    // 2. Extract Amount
    final amount = _extractAmountFromIndonesian(lower);

    // 3. Match Wallet
    String? matchedWalletId;
    String? matchedWalletName;

    if (userWallets != null && userWallets.isNotEmpty) {
      for (var w in userWallets) {
        final wNameLower = w.name.toLowerCase();
        if (lower.contains(wNameLower) ||
            (w.bankName != null && lower.contains(w.bankName!.toLowerCase()))) {
          matchedWalletId = w.id;
          matchedWalletName = w.name;
          break;
        }
      }

      // Default fallback keywords if specific name not found
      if (matchedWalletId == null) {
        if (lower.contains('tunai') || lower.contains('cash')) {
          final cashWallet = userWallets.where((w) => w.type == 'cash').firstOrNull;
          if (cashWallet != null) {
            matchedWalletId = cashWallet.id;
            matchedWalletName = cashWallet.name;
          }
        } else if (lower.contains('gopay') || lower.contains('ovo') || lower.contains('dana')) {
          final ewallet = userWallets.where((w) => w.type == 'e-wallet').firstOrNull;
          if (ewallet != null) {
            matchedWalletId = ewallet.id;
            matchedWalletName = ewallet.name;
          }
        } else if (lower.contains('bca') || lower.contains('bank') || lower.contains('rekening')) {
          final bankWallet = userWallets.where((w) => w.type == 'bank').firstOrNull;
          if (bankWallet != null) {
            matchedWalletId = bankWallet.id;
            matchedWalletName = bankWallet.name;
          }
        }
      }

      // If still null, pick default wallet or first wallet
      if (matchedWalletId == null) {
        final defWallet = userWallets.where((w) => w.isDefault).firstOrNull ?? userWallets.first;
        matchedWalletId = defWallet.id;
        matchedWalletName = defWallet.name;
      }
    }

    // 4. Match Category
    String category = type == TransactionType.income
        ? (incomeCategories?.firstOrNull ?? AppConstants.defaultIncomeCategories.first)
        : (expenseCategories?.firstOrNull ?? AppConstants.defaultExpenseCategories.first);

    if (type == TransactionType.income) {
      if (lower.contains('gaji') || lower.contains('payroll')) {
        category = 'Gaji';
      } else if (lower.contains('bonus') || lower.contains('hadiah') || lower.contains('thr')) {
        category = 'Bonus';
      } else if (lower.contains('investasi') || lower.contains('dividen') || lower.contains('reksadana')) {
        category = 'Investasi';
      } else if (lower.contains('jual') || lower.contains('dagang') || lower.contains('toko')) {
        category = 'Penjualan';
      } else if (lower.contains('ojol') || lower.contains('grab') || lower.contains('gojek')) {
        category = 'Ngojol';
      }
    } else {
      if (lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('nasi') ||
          lower.contains('kopi') ||
          lower.contains('ayam') ||
          lower.contains('bakso') ||
          lower.contains('mie') ||
          lower.contains('resto') ||
          lower.contains('cafe') ||
          lower.contains('warung') ||
          lower.contains('jajan')) {
        category = 'Makanan';
      } else if (lower.contains('bensin') ||
          lower.contains('pertalite') ||
          lower.contains('pertamax') ||
          lower.contains('solar') ||
          lower.contains('spbu') ||
          lower.contains('ojol') ||
          lower.contains('grab') ||
          lower.contains('gojek') ||
          lower.contains('tol') ||
          lower.contains('parkir') ||
          lower.contains('service') ||
          lower.contains('angkot') ||
          lower.contains('busway')) {
        category = 'Transportasi';
      } else if (lower.contains('baju') ||
          lower.contains('sepatu') ||
          lower.contains('celana') ||
          lower.contains('shopee') ||
          lower.contains('tokopedia') ||
          lower.contains('belanja') ||
          lower.contains('mall') ||
          lower.contains('indomaret') ||
          lower.contains('alfamart')) {
        category = 'Belanja';
      } else if (lower.contains('listrik') ||
          lower.contains('pln') ||
          lower.contains('pdam') ||
          lower.contains('air') ||
          lower.contains('wifi') ||
          lower.contains('indihome') ||
          lower.contains('pulsa') ||
          lower.contains('kuota') ||
          lower.contains('bpjs') ||
          lower.contains('tagihan') ||
          lower.contains('kontrakan') ||
          lower.contains('kos')) {
        category = 'Tagihan';
      } else if (lower.contains('obat') ||
          lower.contains('dokter') ||
          lower.contains('apotek') ||
          lower.contains('rumah sakit') ||
          lower.contains('vitamin') ||
          lower.contains('klinik')) {
        category = 'Kesehatan';
      } else if (lower.contains('nonton') ||
          lower.contains('bioskop') ||
          lower.contains('game') ||
          lower.contains('netflix') ||
          lower.contains('spotify') ||
          lower.contains('liburan')) {
        category = 'Hiburan';
      } else if (lower.contains('buku') ||
          lower.contains('sekolah') ||
          lower.contains('kuliah') ||
          lower.contains('kursus') ||
          lower.contains('spp')) {
        category = 'Pendidikan';
      }
    }

    // 5. Clean Title
    String cleanedTitle = speechText;
    final removeWords = [
      'beli',
      'bayar',
      'jajan',
      'dapat',
      'terima',
      'pakai',
      'menggunakan',
      'lewat',
      'sebesar',
      'nominal',
      'rp',
      'rupiah',
      'ke',
      'dari',
      'di',
    ];

    // Remove numbers and currency keywords from title
    cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\b\d+[\.,]?\d*\b'), '');
    cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\b(ribu|rebu|rb|k|juta|jt)\b', caseSensitive: false), '');

    // Remove wallet names from title
    if (userWallets != null) {
      for (var w in userWallets) {
        cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\b' + RegExp.escape(w.name) + r'\b', caseSensitive: false), '');
      }
    }

    // Clean filler words
    for (var w in removeWords) {
      cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\b' + RegExp.escape(w) + r'\b', caseSensitive: false), '');
    }

    cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanedTitle.isEmpty || cleanedTitle.length < 2) {
      cleanedTitle = '$category (${type == TransactionType.income ? 'Masuk' : 'Keluar'})';
    } else {
      // Capitalize first letter
      cleanedTitle = cleanedTitle[0].toUpperCase() + cleanedTitle.substring(1);
    }

    return ParsedVoiceData(
      title: cleanedTitle,
      amount: amount,
      type: type,
      category: category,
      walletId: matchedWalletId,
      walletName: matchedWalletName,
      rawSpeech: speechText,
    );
  }

  double _extractAmountFromIndonesian(String text) {
    // 1. Check patterns like "1.5 juta" or "1,5jt" or "2 juta"
    final millionRegex = RegExp(r'(\d+[\.,]?\d*)\s*(juta|jt)\b');
    final millionMatch = millionRegex.firstMatch(text);
    if (millionMatch != null) {
      final numStr = millionMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) return val * 1000000;
    }

    // 2. Check patterns like "25 ribu", "25rb", "25k", "25rebu"
    final thousandRegex = RegExp(r'(\d+[\.,]?\d*)\s*(ribu|rebu|rb|k)\b');
    final thousandMatch = thousandRegex.firstMatch(text);
    if (thousandMatch != null) {
      final numStr = thousandMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) return val * 1000;
    }

    // 3. Check Indonesian Word Numbers (e.g. "dua puluh lima ribu", "seratus ribu", "satu juta")
    final wordNumberVal = _parseIndonesianWordNumber(text);
    if (wordNumberVal > 0) return wordNumberVal;

    // 4. Raw digits (e.g. "25000", "50000")
    final digitRegex = RegExp(r'(\d{4,})');
    final digitMatch = digitRegex.firstMatch(text);
    if (digitMatch != null) {
      final val = double.tryParse(digitMatch.group(1)!);
      if (val != null) return val;
    }

    return 0;
  }

  double _parseIndonesianWordNumber(String text) {
    final wordMap = {
      'satu': 1,
      'dua': 2,
      'tiga': 3,
      'empat': 4,
      'lima': 5,
      'enam': 6,
      'tujuh': 7,
      'delapan': 8,
      'sembilan': 9,
      'sepuluh': 10,
      'sebelas': 11,
      'seratus': 100,
      'seribu': 1000,
      'sejuta': 1000000,
    };

    double total = 0;
    if (text.contains('sejuta') || text.contains('satu juta')) total += 1000000;
    if (text.contains('seratus ribu')) total += 100000;
    if (text.contains('lima puluh ribu')) total += 50000;
    if (text.contains('dua puluh ribu')) total += 20000;
    if (text.contains('sepuluh ribu')) total += 10000;
    if (text.contains('lima ribu')) total += 5000;
    if (text.contains('dua ribu')) total += 2000;
    if (text.contains('seribu')) total += 1000;

    if (total > 0) return total;

    // Check custom compound like "dua puluh lima ribu"
    for (var entry in wordMap.entries) {
      if (text.contains('${entry.key} puluh lima ribu')) {
        return (entry.value * 10 + 5) * 1000.0;
      }
      if (text.contains('${entry.key} puluh ribu')) {
        return (entry.value * 10) * 1000.0;
      }
      if (text.contains('${entry.key} ratus ribu')) {
        return (entry.value * 100) * 1000.0;
      }
      if (text.contains('${entry.key} juta')) {
        return (entry.value * 1000000.0);
      }
      if (text.contains('${entry.key} ribu')) {
        return (entry.value * 1000.0);
      }
    }

    return 0;
  }
}

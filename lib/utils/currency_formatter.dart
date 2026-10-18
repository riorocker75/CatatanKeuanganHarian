import 'package:flutter/services.dart';

/// Formatter untuk input teks nominal dengan pemisah ribuan titik secara real-time
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hanya ambil digit angka
    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Format dengan titik pemisah ribuan
    final formatted = CurrencyFormatHelper.format(cleanDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Helper utilitas untuk memformat dan membersihkan format nominal Rupiah
class CurrencyFormatHelper {
  /// Memformat angka (int, double, atau String) ke string dengan titik ribuan (misal: 1000000 -> 1.000.000)
  static String format(dynamic value) {
    if (value == null) return '';
    String str;
    if (value is double) {
      str = value.toStringAsFixed(0);
    } else {
      str = value.toString();
    }

    final cleanStr = str.replaceAll('.', '').replaceAll(',', '').trim();
    if (cleanStr.isEmpty) return '';

    final number = int.tryParse(cleanStr);
    if (number == null) return cleanStr;

    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  /// Membersihkan tanda titik, koma, dan spasi untuk siap diparse ke angka
  static String clean(String? value) {
    if (value == null) return '';
    return value.replaceAll('.', '').replaceAll(',', '').trim();
  }

  /// Parsing nilai double bersih dari teks berformat rupiah
  static double parse(String? value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    final cleaned = clean(value);
    return double.tryParse(cleaned) ?? fallback;
  }
}

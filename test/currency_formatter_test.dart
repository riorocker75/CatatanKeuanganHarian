import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:keuangan_harian/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatHelper Tests', () {
    test('Format angka ribuan ke format titik rupiah', () {
      expect(CurrencyFormatHelper.format(1000), equals('1.000'));
      expect(CurrencyFormatHelper.format(25000), equals('25.000'));
      expect(CurrencyFormatHelper.format(500000), equals('500.000'));
      expect(CurrencyFormatHelper.format(1500000), equals('1.500.000'));
      expect(CurrencyFormatHelper.format(1000000000), equals('1.000.000.000'));
      expect(CurrencyFormatHelper.format(500), equals('500'));
      expect(CurrencyFormatHelper.format(0), equals('0'));
      expect(CurrencyFormatHelper.format(''), equals(''));
      expect(CurrencyFormatHelper.format(null), equals(''));
    });

    test('Clean titik dari teks nominal', () {
      expect(CurrencyFormatHelper.clean('1.000.000'), equals('1000000'));
      expect(CurrencyFormatHelper.clean('  50.000  '), equals('50000'));
      expect(CurrencyFormatHelper.clean(''), equals(''));
    });

    test('Parse string berformat titik menjadi double numerik', () {
      expect(CurrencyFormatHelper.parse('1.000.000'), equals(1000000.0));
      expect(CurrencyFormatHelper.parse('25.500'), equals(25500.0));
      expect(CurrencyFormatHelper.parse('0'), equals(0.0));
      expect(CurrencyFormatHelper.parse(''), equals(0.0));
      expect(CurrencyFormatHelper.parse(null), equals(0.0));
      expect(CurrencyFormatHelper.parse('bukan_angka'), equals(0.0));
    });
  });

  group('CurrencyInputFormatter Tests', () {
    final formatter = CurrencyInputFormatter();

    test('Memformat teks saat mengetik angka baru', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '10000',
        selection: TextSelection.collapsed(offset: 5),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('10.000'));
      expect(result.selection.baseOffset, equals(6));
    });

    test('Memformat jutaan saat mengetik', () {
      const oldValue = TextEditingValue(
        text: '100.000',
        selection: TextSelection.collapsed(offset: 7),
      );
      const newValue = TextEditingValue(
        text: '100.0000',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1.000.000'));
    });

    test('Mengosongkan teks saat input kosong', () {
      const oldValue = TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      );
      const newValue = TextEditingValue.empty;

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals(''));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_harian/models/recurring_transaction_model.dart';
import 'package:keuangan_harian/models/transaction_model.dart';

void main() {
  group('RecurringTransactionModel Monthly Logic', () {
    test('Belum masuk di tanggal bulan tersebut -> harus menampung tanggal bulan ini', () {
      final now = DateTime.now();
      // Targetkan tanggal di masa depan pada bulan ini jika memungkinkan,
      // misal jika sekarang tgl 18, target tgl 25
      final futureDay = now.day < 28 ? now.day + 1 : now.day;
      final startDate = DateTime(now.year, now.month, futureDay);
      final lastGen = DateTime(now.year, now.month - 1, futureDay);

      final model = RecurringTransactionModel(
        id: '1',
        userId: 'user1',
        title: 'Gaji',
        amount: 5000000,
        type: TransactionType.income,
        category: 'Gaji',
        frequency: RecurringFrequency.monthly,
        startDate: startDate,
        lastGenerated: lastGen,
        targetDayOfMonth: futureDay,
      );

      final nextDate = model.getRawNextDate();
      expect(nextDate.year, equals(now.year));
      expect(nextDate.month, equals(now.month));
      expect(nextDate.day, equals(futureDay));
    });

    test('Data lama di mana lastGenerated < startDate tapi di bulan yang sama (dummy subtract 1 day)', () {
      final now = DateTime.now();
      final targetDay = now.day < 28 ? now.day + 1 : now.day;
      final startDate = DateTime(now.year, now.month, targetDay);
      // Bug lama: lastGenerated = startDate - 1 hari
      final lastGen = startDate.subtract(const Duration(days: 1));

      final model = RecurringTransactionModel(
        id: '2',
        userId: 'user1',
        title: 'Tagihan WiFi',
        amount: 350000,
        type: TransactionType.expense,
        category: 'Tagihan',
        frequency: RecurringFrequency.monthly,
        startDate: startDate,
        lastGenerated: lastGen,
        targetDayOfMonth: targetDay,
      );

      final nextDate = model.getRawNextDate();
      // Tidak boleh lompat ke bulan depan, harus tetap di bulan ini!
      expect(nextDate.year, equals(now.year));
      expect(nextDate.month, equals(now.month));
      expect(nextDate.day, equals(targetDay));
    });

    test('Sudah pernah dieksekusi di bulan ini -> jadwal berikutnya harus bulan selanjutnya', () {
      final now = DateTime.now();
      final executedDay = now.day;
      final startDate = DateTime(now.year, now.month - 1, executedDay);
      // Sudah dieksekusi di bulan ini:
      final lastGen = DateTime(now.year, now.month, executedDay);

      final model = RecurringTransactionModel(
        id: '3',
        userId: 'user1',
        title: 'Tagihan Listrik',
        amount: 200000,
        type: TransactionType.expense,
        category: 'Tagihan',
        frequency: RecurringFrequency.monthly,
        startDate: startDate,
        lastGenerated: lastGen,
        targetDayOfMonth: executedDay,
      );

      final nextDate = model.getRawNextDate();
      var expectedYear = now.year;
      var expectedMonth = now.month + 1;
      if (expectedMonth > 12) {
        expectedYear += 1;
        expectedMonth = 1;
      }
      expect(nextDate.year, equals(expectedYear));
      expect(nextDate.month, equals(expectedMonth));
      expect(nextDate.day, equals(executedDay));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_harian/models/transaction_model.dart';
import 'package:keuangan_harian/models/budget_model.dart';

void main() {
  group('Hero Card Arus Kas & Color Tests', () {
    test('Arus kas bernilai minus harus berstatus defisit dan berwarna merah', () {
      const double todayIncome = 50000;
      const double todayExpense = 120000;
      final double saldoHariIni = todayIncome - todayExpense;

      expect(saldoHariIni, -70000);
      final bool isNegative = saldoHariIni < 0;
      final bool isPositive = saldoHariIni > 0;
      final Color valueColor = isNegative
          ? const Color(0xFFEF4444)
          : (isPositive ? const Color(0xFF10B981) : Colors.white);
      final String statusLabel = isNegative ? 'Defisit' : (isPositive ? 'Surplus' : 'Seimbang');

      expect(isNegative, true);
      expect(valueColor, const Color(0xFFEF4444));
      expect(statusLabel, 'Defisit');
    });

    test('Arus kas bernilai positif harus berstatus surplus dan berwarna hijau', () {
      const double todayIncome = 250000;
      const double todayExpense = 100000;
      final double saldoHariIni = todayIncome - todayExpense;

      expect(saldoHariIni, 150000);
      final bool isNegative = saldoHariIni < 0;
      final bool isPositive = saldoHariIni > 0;
      final Color valueColor = isNegative
          ? const Color(0xFFEF4444)
          : (isPositive ? const Color(0xFF10B981) : Colors.white);
      final String statusLabel = isNegative ? 'Defisit' : (isPositive ? 'Surplus' : 'Seimbang');

      expect(isPositive, true);
      expect(valueColor, const Color(0xFF10B981));
      expect(statusLabel, 'Surplus');
    });

    test('Arus kas bernilai 0 harus berstatus seimbang dan berwarna putih', () {
      const double todayIncome = 50000;
      const double todayExpense = 50000;
      final double saldoHariIni = todayIncome - todayExpense;

      expect(saldoHariIni, 0);
      final bool isNegative = saldoHariIni < 0;
      final bool isPositive = saldoHariIni > 0;
      final Color valueColor = isNegative
          ? const Color(0xFFEF4444)
          : (isPositive ? const Color(0xFF10B981) : Colors.white);
      final String statusLabel = isNegative ? 'Defisit' : (isPositive ? 'Surplus' : 'Seimbang');

      expect(valueColor, Colors.white);
      expect(statusLabel, 'Seimbang');
    });

    test('Saldo dompet total bila minus harus diberi warna merah', () {
      const double totalWalletNegative = -15000;
      const double totalWalletPositive = 500000;

      final Color negColor = totalWalletNegative < 0 ? const Color(0xFFEF4444) : Colors.white;
      final Color posColor = totalWalletPositive < 0 ? const Color(0xFFEF4444) : Colors.white;

      expect(negColor, const Color(0xFFEF4444));
      expect(posColor, Colors.white);
    });
  });

  group('Kesehatan Budget Harian Reactive Tests', () {
    test('Perhitungan progres budget harus akurat dan clamp maksimal 1.0', () {
      final budget = BudgetModel(
        id: 'b1',
        userId: 'u1',
        amount: 100000,
        period: BudgetPeriod.daily,
        category: 'all',
        createdAt: DateTime.now(),
      );

      // Skenario 1: Belum ada pengeluaran
      double spending = 0.0;
      double progress = budget.amount > 0 ? (spending / budget.amount).clamp(0.0, 1.0) : 0.0;
      expect(progress, 0.0);

      // Skenario 2: 50% terpakai
      spending = 50000.0;
      progress = budget.amount > 0 ? (spending / budget.amount).clamp(0.0, 1.0) : 0.0;
      expect(progress, 0.5);

      // Skenario 3: Overbudget (150.000 terpakai dari 100.000) -> progress clamped 1.0
      spending = 150000.0;
      progress = budget.amount > 0 ? (spending / budget.amount).clamp(0.0, 1.0) : 0.0;
      expect(progress, 1.0);
    });
  });

  group('Chart Grouping & Metrics Tests', () {
    test('Agregasi Pemasukan vs Pengeluaran Bulanan dan 7 Hari', () {
      final now = DateTime.now();
      final txList = [
        // Transaksi Hari ini: Masuk 200k, Keluar 50k
        TransactionModel(
          id: '1',
          userId: 'u1',
          title: 'Gaji',
          amount: 200000,
          type: TransactionType.income,
          category: 'Gaji',
          date: now,
          createdAt: now,
        ),
        TransactionModel(
          id: '2',
          userId: 'u1',
          title: 'Makan',
          amount: 50000,
          type: TransactionType.expense,
          category: 'Makanan',
          date: now,
          createdAt: now,
        ),
        // Transaksi 3 hari lalu: Keluar 30k
        TransactionModel(
          id: '3',
          userId: 'u1',
          title: 'Bensin',
          amount: 30000,
          type: TransactionType.expense,
          category: 'Transport',
          date: now.subtract(const Duration(days: 3)),
          createdAt: now.subtract(const Duration(days: 3)),
        ),
      ];

      final totalIncome = txList
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);
      final totalExpense = txList
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, t) => sum + t.amount);
      final netCashflow = totalIncome - totalExpense;

      expect(totalIncome, 200000);
      expect(totalExpense, 80000);
      expect(netCashflow, 120000);
      expect(netCashflow > 0, true);
    });
  });
}

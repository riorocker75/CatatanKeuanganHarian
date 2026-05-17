import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_card.dart';
import 'add_transaction_screen.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Silakan login'));

    final transactionService = TransactionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: transactionService.getUserTransactions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada transaksi',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Group by date
          Map<String, List<TransactionModel>> grouped = {};
          for (var t in transactions) {
            final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
            grouped.putIfAbsent(dateKey, () => []).add(t);
          }

          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final dateTransactions = grouped[dateKey]!;
              final date = DateTime.parse(dateKey);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildDailyTotal(dateTransactions),
                      ],
                    ),
                  ),
                  ...dateTransactions.map((t) => TransactionCard(
                        transaction: t,
                        onDelete: () async {
                          await transactionService.deleteTransaction(t);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaksi dihapus'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                transaction: t,
                              ),
                            ),
                          );
                        },
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDailyTotal(List<TransactionModel> transactions) {
    double income = 0;
    double expense = 0;

    for (var t in transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    final format = NumberFormat.compactCurrency(
      locale: 'id_ID',
      symbol: 'Rp',
    );

    return Row(
      children: [
        if (income > 0)
          Text(
            '+${format.format(income)}',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        if (expense > 0) ...[
          if (income > 0) const SizedBox(width: 8),
          Text(
            '-${format.format(expense)}',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
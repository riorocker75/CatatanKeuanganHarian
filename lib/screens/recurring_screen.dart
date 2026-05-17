import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction_model.dart';
import '../services/recurring_service.dart';
import 'add_recurring_screen.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));

    final recurringService = RecurringService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Rutin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddRecurringScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringTransactionModel>>(
        stream: recurringService.getUserRecurring(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final recurringList = snapshot.data!;

          if (recurringList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada transaksi rutin',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddRecurringScreen()),
                      );
                    },
                    child: const Text('Tambah Transaksi Rutin'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: recurringList.length,
            itemBuilder: (context, index) {
              final item = recurringList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.isActive ? Colors.white : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isActive ? Colors.grey.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.repeat, color: Colors.red.shade400, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: item.isActive ? null : TextDecoration.lineThrough,
                                  color: item.isActive ? Colors.black : Colors.grey,
                                ),
                              ),
                              Text(
                                item.category,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: item.isActive,
                          onChanged: (value) async {
                            await recurringService.updateRecurring(
                              item.copyWith(isActive: value),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getFrequencyLabel(item.frequency),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'Rp ${item.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Berikutnya: ${_formatDate(item.getNextDate())}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getFrequencyLabel(RecurringFrequency freq) {
    switch (freq) {
      case RecurringFrequency.daily:
        return 'Setiap Hari';
      case RecurringFrequency.weekly:
        return 'Setiap Minggu';
      case RecurringFrequency.monthly:
        return 'Setiap Bulan';
      case RecurringFrequency.yearly:
        return 'Setiap Tahun';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
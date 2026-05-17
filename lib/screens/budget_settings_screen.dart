import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/budget_model.dart';
import '../services/budget_service.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final BudgetService _budgetService = BudgetService();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  String _selectedCategory = 'all';
  bool _notifyWhenExceeded = true;

  final List<String> _categories = [
    'all',
    'Makanan',
    'Transportasi',
    'Belanja',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Lainnya',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (_amountController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak login');

      final budget = BudgetModel(
        id: '',
        userId: user.uid,
        amount: double.parse(_amountController.text),
        period: _selectedPeriod,
        category: _selectedCategory,
        createdAt: DateTime.now(),
        notifyWhenExceeded: _notifyWhenExceeded,
      );

      await _budgetService.setBudget(budget);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Budget')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Budgets List
            StreamBuilder<List<BudgetModel>>(
              stream: _budgetService.getUserBudgets(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Belum ada budget yang diatur',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget Aktif',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...snapshot.data!.map((budget) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              budget.period == BudgetPeriod.daily
                                  ? Icons.today
                                  : Icons.calendar_month,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  budget.period == BudgetPeriod.daily
                                      ? 'Budget Harian'
                                      : 'Budget Bulanan',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  budget.category == 'all'
                                      ? 'Semua Kategori'
                                      : budget.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Rp ${budget.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            const Text(
              'Tambah Budget Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Period Selection
            const Text('Periode', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodButton('Harian', BudgetPeriod.daily),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPeriodButton('Bulanan', BudgetPeriod.monthly),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Selection
            const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _categories.contains(_selectedCategory)
                  ? _selectedCategory
                  : _categories.first,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category == 'all' ? 'Semua Kategori' : category),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            const SizedBox(height: 20),

            // Amount
            const Text('Jumlah Budget', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Contoh: 500000',
              ),
            ),
            const SizedBox(height: 16),

            // Notification Toggle
            SwitchListTile(
              title: const Text('Notifikasi saat terlampaui'),
              subtitle: const Text('Kirim alert ketika pengeluaran melebihi budget'),
              value: _notifyWhenExceeded,
              onChanged: (value) => setState(() => _notifyWhenExceeded = value),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SIMPAN BUDGET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, BudgetPeriod period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
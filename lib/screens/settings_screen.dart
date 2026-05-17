import 'package:flutter/material.dart';
import 'package:keuangan_harian/screens/category_screen.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../services/export_service.dart';
import '../services/transaction_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wallet_screen.dart';
import 'recurring_screen.dart';
import '/screens/budget_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Profile Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pengguna Aktif',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Appearance Section
          _buildSectionHeader('Tampilan'),
          SwitchListTile(
            title: const Text('Mode Gelap'),
            subtitle: const Text('Ubah tampilan aplikasi menjadi gelap'),
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Colors.green.shade600,
            ),
          ),
          const Divider(),

          // Data Section
          _buildSectionHeader('Data'),
          ListTile(
            leading: Icon(Icons.download, color: Colors.green.shade600),
            title: const Text('Export ke PDF'),
            subtitle: const Text('Simpan laporan ke file PDF'),
            trailing: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isExporting ? null : () => _exportToPDF(user?.uid),
          ),
          ListTile(
            leading: Icon(Icons.table_chart, color: Colors.green.shade600),
            title: const Text('Export ke CSV'),
            subtitle: const Text('Simpan data ke file CSV/Excel'),
            trailing: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isExporting ? null : () => _exportToCSV(user?.uid),
          ),
          const Divider(),

          // Budget Section
          _buildSectionHeader('Budget & Dompet'),
          ListTile(
            leading: Icon(Icons.account_balance_wallet, color: Colors.green.shade600),
            title: const Text('Pengaturan Budget'),
            subtitle: const Text('Atur batas pengeluaran harian/bulanan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.wallet, color: Colors.green.shade600),
            title: const Text('Dompet Saya'),
            subtitle: const Text('Kelola sumber dana'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            );
          },
          ),
          const Divider(),
        _buildSectionHeader('Kategori'),
          ListTile(
              leading: Icon(Icons.category, color: Colors.green.shade600),
              title: const Text('Kategori Pengeluaran'),
              subtitle: const Text('Tambah/edit kategori custom'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen(type: 'expense')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.category, color: Colors.blue.shade600),
              title: const Text('Kategori Pemasukan'),
              subtitle: const Text('Tambah/edit kategori custom'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen(type: 'income')),
                );
              },
            ),
            const Divider(),
          // Recurring Section
          _buildSectionHeader('Transaksi'),
          ListTile(
            leading: Icon(Icons.repeat, color: Colors.green.shade600),
            title: const Text('Transaksi Rutin'),
            subtitle: const Text('Kelola pengeluaran berulang'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringScreen()),
              );
            },
          ),
          const Divider(),

          // About Section
          _buildSectionHeader('Tentang'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versi Aplikasi'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Dev Ucore'),
            subtitle: Text('© 2026 Keuangan Harian'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
        ),
      ),
    );
  }

  Future<void> _exportToPDF(String? userId) async {
    if (userId == null) return;

    setState(() => _isExporting = true);
    try {
      final transactionService = TransactionService();
      final exportService = ExportService();

      final transactions = await transactionService.getUserTransactions(userId).first;
      await exportService.exportToPDF(transactions, title: 'Laporan Keuangan');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil dibuat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToCSV(String? userId) async {
    if (userId == null) return;

    setState(() => _isExporting = true);
    try {
      final transactionService = TransactionService();
      final exportService = ExportService();

      final transactions = await transactionService.getUserTransactions(userId).first;
      await exportService.exportToCSV(transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV berhasil dibuat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
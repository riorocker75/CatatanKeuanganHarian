import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../services/export_service.dart';
import '../services/transaction_service.dart';
import '../services/auth_service.dart';
import 'category_screen.dart';
import 'wallet_screen.dart';
import 'recurring_screen.dart';
import 'budget_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@')[0] ?? 'User');
    final userEmail = user?.email ?? '-';
    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Profile Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF10B981), const Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF10B981)).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Pengguna Aktif',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // GROUP 1: Tampilan & Preferensi
          _buildSectionTitle('TAMPILAN & PREFERENSI', isDark),
          _buildCardContainer(
            isDark: isDark,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                activeColor: const Color(0xFF10B981),
                secondary: _buildIconBadge(
                  icon: themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                title: const Text('Mode Gelap (Dark Mode)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Ganti tema gelap untuk kenyamanan mata', style: TextStyle(fontSize: 11)),
                value: themeProvider.isDarkMode,
                onChanged: (_) {
                  HapticFeedback.selectionClick();
                  themeProvider.toggleTheme();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GROUP 2: Ekspor Data & Laporan
          _buildSectionTitle('EKSPOR DATA & LAPORAN', isDark),
          _buildCardContainer(
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Export ke PDF',
                subtitle: 'Simpan ringkasan transaksi dalam dokumen PDF',
                trailing: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                      )
                    : null,
                onTap: _isExporting ? null : () => _exportToPDF(user?.uid),
              ),
              _buildDivider(isDark),
              _buildTile(
                icon: Icons.table_chart_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Export ke CSV / Excel',
                subtitle: 'Unduh seluruh riwayat data transaksi ke file spreadsheet',
                trailing: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                      )
                    : null,
                onTap: _isExporting ? null : () => _exportToCSV(user?.uid),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GROUP 3: Manajemen Keuangan
          _buildSectionTitle('MANAJEMEN KEUANGAN', isDark),
          _buildCardContainer(
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.track_changes_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Pengaturan Target Budget',
                subtitle: 'Setel batas anggaran pengeluaran harian atau bulanan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
                ),
              ),
              _buildDivider(isDark),
              _buildTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Dompet & Rekening',
                subtitle: 'Kelola akun bank, e-wallet, dan saldo tunai',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GROUP 4: Kategori & Transaksi
          _buildSectionTitle('KATEGORI & RUTINITAS', isDark),
          _buildCardContainer(
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFFEF4444),
                title: 'Kategori Pengeluaran',
                subtitle: 'Tambah atau edit kategori pengeluaran custom',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen(type: 'expense')),
                ),
              ),
              _buildDivider(isDark),
              _buildTile(
                icon: Icons.monetization_on_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Kategori Pemasukan',
                subtitle: 'Tambah atau edit kategori sumber penghasilan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryScreen(type: 'income')),
                ),
              ),
              _buildDivider(isDark),
              _buildTile(
                icon: Icons.event_repeat_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Transaksi Rutin & Gaji',
                subtitle: 'Jadwal otomatisasi pemasukan / tagihan berkala',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecurringScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GROUP 5: Informasi Aplikasi & Logout
          _buildSectionTitle('INFORMASI & AKUN', isDark),
          _buildCardContainer(
            isDark: isDark,
            children: [
              _buildTile(
                icon: Icons.info_outline_rounded,
                iconColor: Colors.blueGrey,
                title: 'Versi Aplikasi',
                subtitle: 'v1.0.0 (Release Fintech Edition)',
                showArrow: false,
              ),
              _buildDivider(isDark),
              _buildTile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Keluar Akun (Logout)',
                subtitle: 'Keluar dari sesi akun saat ini',
                showArrow: false,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await _authService.logout(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildIconBadge({required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool showArrow = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildIconBadge(icon: icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: trailing ?? (showArrow ? const Icon(Icons.chevron_right_rounded, size: 20) : null),
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 58,
      endIndent: 16,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Dokumen PDF berhasil dibuat'),
            backgroundColor: Color(0xFF10B981),
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
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ File CSV / Excel berhasil dibuat'),
            backgroundColor: Color(0xFF10B981),
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
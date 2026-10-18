import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modern Fintech Hero Balance Card with Eye Privacy Toggle,
/// Daily Cashflow Badges, and Multi-Wallet Overview.
class BalanceSwipeCard extends StatefulWidget {
  final double todayIncome;
  final double todayExpense;
  final double totalWalletBalance;
  final int walletCount;
  final VoidCallback? onTapWallet;
  final VoidCallback? onTapIncome;
  final VoidCallback? onTapExpense;
  final VoidCallback? onTapTransfer;
  final VoidCallback? onTapRecurring;
  final VoidCallback? onTapAdd;

  const BalanceSwipeCard({
    super.key,
    required this.todayIncome,
    required this.todayExpense,
    required this.totalWalletBalance,
    required this.walletCount,
    this.onTapWallet,
    this.onTapIncome,
    this.onTapExpense,
    this.onTapTransfer,
    this.onTapRecurring,
    this.onTapAdd,
  });

  @override
  State<BalanceSwipeCard> createState() => _BalanceSwipeCardState();
}

class _BalanceSwipeCardState extends State<BalanceSwipeCard> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _isBalanceHidden = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacyState();
  }

  Future<void> _loadPrivacyState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBalanceHidden = prefs.getBool('hide_balance_privacy') ?? false;
    });
  }

  Future<void> _togglePrivacyState() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBalanceHidden = !_isBalanceHidden;
    });
    await prefs.setBool('hide_balance_privacy', _isBalanceHidden);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatRupiah(double value) {
    if (_isBalanceHidden) return 'Rp ••••••••';
    final s = value.abs().toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    final sign = value < 0 ? '-' : '';
    return '${sign}Rp $buffer';
  }

  String _formatSignedRupiah(double value) {
    if (_isBalanceHidden) return 'Rp ••••••••';
    final s = value.abs().toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    if (value < 0) {
      return '-Rp $buffer';
    } else if (value > 0) {
      return '+Rp $buffer';
    }
    return 'Rp 0';
  }

  @override
  Widget build(BuildContext context) {
    final saldoHariIni = widget.todayIncome - widget.todayExpense;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Swipeable Hero Card
        SizedBox(
          height: 205,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            children: [
              // Slide 1: Total Saldo & Arus Kas Hari Ini
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTotalBalanceSlide(saldoHariIni, isDark),
              ),
              // Slide 2: Ringkasan Saldo Dompet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildWalletOverviewSlide(isDark),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Page Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 6,
              height: 5,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // 4 Quick Fintech Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionButton(
                icon: Icons.arrow_downward_rounded,
                label: 'Pemasukan',
                color: const Color(0xFF10B981),
                isDark: isDark,
                onTap: widget.onTapIncome,
              ),
              _buildQuickActionButton(
                icon: Icons.arrow_upward_rounded,
                label: 'Pengeluaran',
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: widget.onTapExpense,
              ),
              _buildQuickActionButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer',
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                onTap: widget.onTapTransfer,
              ),
              _buildQuickActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Dompet',
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: widget.onTapWallet,
              ),
              _buildQuickActionButton(
                icon: Icons.update_rounded,
                label: 'Rutin',
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                onTap: widget.onTapRecurring,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalBalanceSlide(double saldoHariIni, bool isDark) {
    final bool isNegative = saldoHariIni < 0;
    final bool isPositive = saldoHariIni > 0;
    final Color valueColor = isNegative
        ? const Color(0xFFEF4444)
        : (isPositive ? const Color(0xFF10B981) : Colors.white);
    final Color badgeBgColor = isNegative
        ? const Color(0xFFEF4444).withValues(alpha: 0.16)
        : (isPositive ? const Color(0xFF10B981).withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.12));
    final Color iconColor = isNegative
        ? const Color(0xFFFCA5A5)
        : (isPositive ? const Color(0xFF6EE7B7) : Colors.white70);
    final IconData statusIcon = isNegative
        ? Icons.trending_down_rounded
        : (isPositive ? Icons.trending_up_rounded : Icons.account_balance_wallet_rounded);
    final String statusLabel = isNegative ? 'Defisit' : (isPositive ? 'Surplus' : 'Seimbang');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle glowing circle decoration
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isNegative
                        ? const Color(0xFFEF4444)
                        : (isPositive ? const Color(0xFF10B981) : Colors.blue))
                    .withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Label + Eye Privacy Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(statusIcon, color: iconColor, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Arus Kas Hari Ini',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: valueColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _togglePrivacyState,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isBalanceHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),

              // Hero Signed Cashflow Value (colored red if minus, green if positive)
              Text(
                _formatSignedRupiah(saldoHariIni),
                style: TextStyle(
                  color: valueColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),

              // Bottom Row: Today's Income & Expense Badges
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    // Income
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onTapIncome,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Masuk Hari Ini', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                                  Text(
                                    _formatRupiah(widget.todayIncome),
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.12)),
                    const SizedBox(width: 8),

                    // Expense
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onTapExpense,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFFEF4444)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Keluar Hari Ini', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                                  Text(
                                    _formatRupiah(widget.todayExpense),
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletOverviewSlide(bool isDark) {
    return GestureDetector(
      onTap: widget.onTapWallet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.12),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Dompet & Rekening Aktif',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _togglePrivacyState,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isBalanceHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Kelola',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatRupiah(widget.totalWalletBalance),
                      style: TextStyle(
                        color: widget.totalWalletBalance < 0
                            ? const Color(0xFFEF4444)
                            : Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Terbagi dalam ${widget.walletCount} akun dompet / rekening',
                      style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF93C5FD)),
                      SizedBox(width: 6),
                      Text(
                        'Ketuk di sini untuk tambah atau kelola saldo dompet',
                        style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
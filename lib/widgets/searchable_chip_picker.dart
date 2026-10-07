import 'package:flutter/material.dart';


class SearchableChipItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? subtitle;
  final String? badgeText;

  const SearchableChipItem({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.badgeText,
  });
}

class SearchableChipPicker<T> {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<SearchableChipItem<T>> items,
    T? selectedValue,
    Color activeColor = const Color(0xFF10B981),
    Widget? actionButton,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _SearchableChipSheet<T>(
          title: title,
          items: items,
          selectedValue: selectedValue,
          activeColor: activeColor,
          actionButton: actionButton,
        );
      },
    );
  }
}

class _SearchableChipSheet<T> extends StatefulWidget {
  final String title;
  final List<SearchableChipItem<T>> items;
  final T? selectedValue;
  final Color activeColor;
  final Widget? actionButton;

  const _SearchableChipSheet({
    required this.title,
    required this.items,
    this.selectedValue,
    required this.activeColor,
    this.actionButton,
  });

  @override
  State<_SearchableChipSheet<T>> createState() => _SearchableChipSheetState<T>();
}

class _SearchableChipSheetState<T> extends State<_SearchableChipSheet<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.items.where((item) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item.label.toLowerCase().contains(q) ||
          (item.subtitle != null && item.subtitle!.toLowerCase().contains(q));
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title & Manage Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (widget.actionButton != null) widget.actionButton!,
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Cari ${widget.title.toLowerCase()}...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: widget.activeColor, size: 20),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
            const SizedBox(height: 16),

            // Round Label Chips
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Tidak ditemukan',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filtered.map((item) {
                          final isSelected = item.value == widget.selectedValue;

                          return InkWell(
                            onTap: () => Navigator.pop(context, item.value),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.activeColor.withOpacity(isDark ? 0.25 : 0.15)
                                    : (isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? widget.activeColor
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.icon != null) ...[
                                    Icon(
                                      item.icon,
                                      size: 18,
                                      color: isSelected ? widget.activeColor : (item.iconColor ?? Colors.grey.shade500),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected
                                          ? (isDark ? Colors.white : widget.activeColor)
                                          : (isDark ? Colors.grey.shade300 : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  if (item.subtitle != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${item.subtitle})',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                  if (item.badgeText != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.badgeText!,
                                        style: TextStyle(fontSize: 9, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.check_circle_rounded, size: 16, color: widget.activeColor),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

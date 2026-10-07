import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import '../utils/constants.dart';

class CategoryScreen extends StatefulWidget {
  final String type;

  const CategoryScreen({super.key, required this.type});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final CategoryService _categoryService = CategoryService();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _editingId;
  IconData? _selectedIcon;

  final List<IconData> _icons = [
    Icons.restaurant, Icons.directions_car, Icons.shopping_bag,
    Icons.receipt_long, Icons.movie, Icons.local_hospital, Icons.school,
    Icons.work, Icons.card_giftcard, Icons.trending_up, Icons.home,
    Icons.phone_android, Icons.computer, Icons.fitness_center,
    Icons.storefront, Icons.two_wheeler, Icons.local_cafe,
    Icons.pets, Icons.flight, Icons.build,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _clear() {
    _nameController.clear();
    _editingId = null;
    _selectedIcon = null;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final category = CategoryModel(
        id: _editingId ?? '',
        userId: user.uid,
        name: name,
        type: widget.type,
        icon: _selectedIcon ?? AppConstants.getCategoryIcon(name),
        createdAt: DateTime.now(),
      );

      if (_editingId != null) {
        await _categoryService.updateCategory(category);
      } else {
        await _categoryService.addCategory(category);
      }

      if (mounted) {
        _clear();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingId != null ? 'Kategori diperbarui' : 'Kategori ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Hapus kategori "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _categoryService.deleteCategory(id);
    }
  }

  void _showDialog({CategoryModel? category}) {
    if (category != null) {
      _editingId = category.id;
      _nameController.text = category.name;
      _selectedIcon = category.icon;
    } else {
      _clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category != null ? 'Edit Kategori' : 'Tambah Kategori Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori',
                  hintText: 'Contoh: Hobi, Cicilan, Skincare',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Icon Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _icons.map((icon) {
                      final isSelected = _selectedIcon == icon;
                      return GestureDetector(
                        onTap: () => setModalState(() => _selectedIcon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (widget.type == 'income' ? Colors.green.shade600 : Colors.red.shade600)
                                : Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            size: 22,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.type == 'income' ? Colors.green.shade600 : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          category != null ? 'PERBARUI KATEGORI' : 'SIMPAN KATEGORI',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).then((_) => _clear());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Silakan login')));

    final isIncome = widget.type == 'income';
    final defaults = isIncome
        ? AppConstants.defaultIncomeCategories
        : AppConstants.defaultExpenseCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(isIncome ? 'Kategori Pemasukan' : 'Kategori Pengeluaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Kategori',
            onPressed: () => _showDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: _categoryService.getUserCategories(user.uid, widget.type),
        builder: (context, snapshot) {
          final custom = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader('Kategori Bawaan (Default)'),
              ...defaults.map((name) => _buildItem(
                    name: name,
                    isDefault: true,
                    icon: AppConstants.getCategoryIcon(name),
                  )),

              const SizedBox(height: 24),
              _buildHeader('Kategori Tambahan Anda'),
              if (custom.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada kategori kustom',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ...custom.map((c) => _buildItem(
                    name: c.name,
                    isDefault: false,
                    icon: c.icon ?? AppConstants.getCategoryIcon(c.name),
                    onEdit: () => _showDialog(category: c),
                    onDelete: () => _delete(c.id, c.name),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildItem({
    required String name,
    required bool isDefault,
    IconData? icon,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = widget.type == 'income';
    final primaryColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final cardContent = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon ?? Icons.category_rounded,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Default',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Geser',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.swipe_left_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                ),
              ],
            ),
        ],
      ),
    );

    if (isDefault) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: cardContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(name),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.44,
          children: [
            if (onEdit != null)
              CustomSlidableAction(
                onPressed: (_) {
                  HapticFeedback.lightImpact();
                  onEdit();
                },
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 16),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (onDelete != null)
              CustomSlidableAction(
                onPressed: (_) {
                  HapticFeedback.mediumImpact();
                  onDelete();
                },
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 16),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Hapus',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      ),
    );
  }
}
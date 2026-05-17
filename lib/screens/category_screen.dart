import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';

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
    Icons.movie, Icons.local_hospital, Icons.school,
    Icons.work, Icons.trending_up, Icons.home,
    Icons.phone, Icons.computer, Icons.fitness_center,
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
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final category = CategoryModel(
        id: _editingId ?? '',
        userId: user.uid,
        name: _nameController.text.trim(),
        type: widget.type,
        icon: _selectedIcon,
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
                category != null ? 'Edit Kategori' : 'Tambah Kategori',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.done,  
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: 'Nama Kategori',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Icon', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((icon) {
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setModalState(() => _selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  );
                }).toList(),
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
                      : Text(category != null ? 'PERBARUI' : 'TAMBAH'),
                ),
              ),
              const SizedBox(height: 20),
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
        ? ['Ngojol']
        : ['Makanan'];

    return Scaffold(
      appBar: AppBar(
        title: Text(isIncome ? 'Kategori Pemasukan' : 'Kategori Pengeluaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
              _buildHeader('Kategori Default'),
              ...defaults.map((name) => _buildItem(name: name, isDefault: true)),

              const SizedBox(height: 24),
              _buildHeader('Kategori Custom'),
              if (custom.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('Belum ada kategori custom', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ...custom.map((c) => _buildItem(
                name: c.name,
                isDefault: false,
                icon: c.icon,
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
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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
    return Container(
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
              color: isDefault ? Colors.grey.shade100 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon ?? Icons.category,
              color: isDefault ? Colors.grey.shade600 : Colors.green.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
          if (!isDefault) ...[
            IconButton(icon: const Icon(Icons.edit, size: 20), color: Colors.blue, onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, size: 20), color: Colors.red, onPressed: onDelete),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Default', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }
}
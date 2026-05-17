import 'package:flutter/material.dart';
import '../models/wallet_model.dart';

class WalletBottomSheet extends StatefulWidget {
  final bool isEditing;
  final WalletModel? wallet;
  final VoidCallback onSave;

  const WalletBottomSheet({
    super.key,
    this.isEditing = false,
    this.wallet,
    required this.onSave,
  });

  @override
  State<WalletBottomSheet> createState() => _WalletBottomSheetState();
}

class _WalletBottomSheetState extends State<WalletBottomSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  String _selectedType = 'cash';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _walletTypes = [
    {'value': 'cash', 'label': 'Cash / Tunai', 'icon': Icons.money},
    {'value': 'bank', 'label': 'Bank Account', 'icon': Icons.account_balance},
    {'value': 'e-wallet', 'label': 'E-Wallet', 'icon': Icons.phone_android},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.wallet != null) {
      _nameController.text = widget.wallet!.name;
      _balanceController.text = widget.wallet!.balance.toString();
      _accountNumberController.text = widget.wallet!.accountNumber ?? '';
      _bankNameController.text = widget.wallet!.bankName ?? '';
      _selectedType = widget.wallet!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing ? 'Edit Dompet' : 'Tambah Dompet Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Wallet Type
              const Text('Tipe Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: _walletTypes.map((type) {
                  final isSelected = _selectedType == type['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = type['value']),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              type['icon'],
                              color: isSelected ? Colors.white : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type['label'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Form Fields
              _buildTextField(
                controller: _nameController,
                label: 'Nama Dompet',
                hint: 'Contoh: Dompet Utama',
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _balanceController,
                label: 'Saldo',
                prefix: 'Rp ',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              if (_selectedType == 'bank') ...[
                _buildTextField(
                  controller: _bankNameController,
                  label: 'Nama Bank',
                  hint: 'Contoh: BCA, Mandiri, BRI',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _accountNumberController,
                  label: 'Nomor Rekening',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],

              if (_selectedType == 'e-wallet') ...[
                _buildTextField(
                  controller: _accountNumberController,
                  label: 'Nomor Telepon / ID',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    setState(() => _isLoading = true);
                    widget.onSave();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.isEditing ? 'PERBARUI DOMPET' : 'TAMBAH DOMPET',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
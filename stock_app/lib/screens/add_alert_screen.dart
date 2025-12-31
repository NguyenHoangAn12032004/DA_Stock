import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class AddAlertScreen extends StatefulWidget {
  const AddAlertScreen({super.key});

  @override
  State<AddAlertScreen> createState() => _AddAlertScreenState();
}

class _AddAlertScreenState extends State<AddAlertScreen> {
  final _symbolController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedType = 'Price';
  String _selectedCondition = 'Above';

  final List<String> _types = ['Price', 'Indicators', 'News'];
  final List<String> _conditions = ['Above', 'Below', 'Increases by', 'Decreases by'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Alert'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveAlert,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('ASSET', isDark),
            const SizedBox(height: 8),
            TextField(
              controller: _symbolController,
              decoration: _inputDecoration('e.g. AAPL, BTC/USD', isDark),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 24),
            
            _buildSectionLabel('ALERT TYPE', isDark),
            const SizedBox(height: 8),
            _buildDropdown(_types, _selectedType, (val) {
              setState(() => _selectedType = val!);
            }, isDark),
            
            if (_selectedType != 'News') ...[
              const SizedBox(height: 24),
              _buildSectionLabel('CONDITION', isDark),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildDropdown(_conditions, _selectedCondition, (val) {
                      setState(() => _selectedCondition = val!);
                    }, isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Value', isDark),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getPreviewText(),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF111418),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPreviewText() {
    String symbol = _symbolController.text.isEmpty ? 'Asset' : _symbolController.text.toUpperCase();
    if (_selectedType == 'News') {
      return 'Notify me when there is breaking news for $symbol';
    }
    String value = _valueController.text.isEmpty ? '...' : _valueController.text;
    return 'Notify me when $symbol price is $_selectedCondition $value';
  }

  Future<void> _saveAlert() async {
    if (_symbolController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a symbol')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final value = double.tryParse(_valueController.text) ?? 0.0;
      final ApiService api = ApiService();
      
      await api.createAlert(
        user.uid,
        _symbolController.text.toUpperCase(),
        _selectedCondition,
        value,
        type: _selectedType,
      );
      
      if (mounted) Navigator.pop(context); // Pop loading
      if (mounted) Navigator.pop(context, true); // Pop screen with success
      
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
      ),
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String value, Function(String?) onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white : Colors.black),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111418),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/alert_provider.dart';
import '../theme/app_colors.dart';
import '../core/utils/stock_utils.dart';

class AddAlertBottomSheet extends ConsumerStatefulWidget {
  final String symbol;

  const AddAlertBottomSheet({super.key, required this.symbol});

  @override
  ConsumerState<AddAlertBottomSheet> createState() => _AddAlertBottomSheetState();
}

class _AddAlertBottomSheetState extends ConsumerState<AddAlertBottomSheet> {
  final _priceController = TextEditingController();
  String _selectedCondition = 'Above'; // or Below
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set Alert for ${widget.symbol}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Above', child: Text('Price Above')),
                    DropdownMenuItem(value: 'Below', child: Text('Price Below')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCondition = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target Price',
                      border: const OutlineInputBorder(),
                      prefixText: StockUtils.isVnStock(widget.symbol) ? '' : '\$ ',
                      suffixText: StockUtils.isVnStock(widget.symbol) ? '₫' : '',
                    ),
                  ),
                ),

            ],
          ),
          const SizedBox(height: 10),
          if (_error != null)
             Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create Alert', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final priceText = _priceController.text;
    final price = double.tryParse(priceText);
    
    if (price == null || price <= 0) {
      setState(() => _error = "Invalid price");
      return;
    }

    setState(() { 
      _isLoading = true; 
      _error = null;
    });

    try {
      await ref.read(alertControllerProvider.notifier).createAlert(
        widget.symbol,
        price,
        _selectedCondition,
      );
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alert created successfully!"))
      );

    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

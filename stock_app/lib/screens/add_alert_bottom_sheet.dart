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
  
  // Alert Types
  String _alertType = 'Price'; // 'Price' or 'RSI'
  
  // Conditions
  String _selectedCondition = 'Above'; // or Below
  
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final isRSI = _alertType == 'RSI';
    final isVnStock = StockUtils.isVnStock(widget.symbol);

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
            'Tạo Cảnh báo cho ${widget.symbol}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // 1. Select Alert Type
          DropdownButtonFormField<String>(
            value: _alertType,
            decoration: const InputDecoration(
              labelText: 'Loại Cảnh báo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Price', child: Text('Giá (Price)')),
              DropdownMenuItem(value: 'RSI', child: Text('Chỉ số RSI')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _alertType = val;
                  _priceController.clear();
                  _selectedCondition = 'Above'; // Reset to default
                });
              }
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // 2. Select Condition
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Điều kiện',
                    border: OutlineInputBorder(),
                  ),
                  items: isRSI 
                    ? const [
                        DropdownMenuItem(value: 'Above', child: Text('RSI > (Cao hơn)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Below', child: Text('RSI < (Thấp hơn)', style: TextStyle(fontSize: 13))),
                      ]
                    : const [
                        DropdownMenuItem(value: 'Above', child: Text('Giá >= (Cao hơn)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Below', child: Text('Giá <= (Thấp hơn)', style: TextStyle(fontSize: 13))),
                      ],
                  isExpanded: true, // Prevent overflow logic
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCondition = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // 3. Enter Value
              Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isRSI ? 'Ngưỡng RSI (0-100)' : 'Mức Giá',
                      border: const OutlineInputBorder(),
                      prefixText: isRSI ? '' : (isVnStock ? '' : '\$ '),
                      suffixText: isRSI ? '' : (isVnStock ? '₫' : ''),
                    ),
                  ),
                ),

            ],
          ),
          const SizedBox(height: 8),
          if (isRSI) 
            const Text(
              "💡 Gợi ý: RSI > 70 (Quá mua - Nên bán), RSI < 30 (Quá bán - Nên mua)",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
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
                : const Text('Tạo Cảnh báo', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final valueText = _priceController.text;
    final value = double.tryParse(valueText);
    
    // Validation
    if (value == null || value <= 0) {
      setState(() => _error = "Vui lòng nhập giá trị hợp lệ");
      return;
    }
    
    if (_alertType == 'RSI' && (value > 100)) {
       setState(() => _error = "RSI phải nhỏ hơn hoặc bằng 100");
       return;
    }

    setState(() { 
      _isLoading = true; 
      _error = null;
    });

    try {
      // Map frontend condition to backend format
      // Price: 'Above', 'Below' -> Backend: 'Above', 'Below'
      // RSI: 'Above', 'Below' -> Backend: 'RSI_Above', 'RSI_Below'
      
      String finalCondition = _selectedCondition;
      if (_alertType == 'RSI') {
        finalCondition = 'RSI_$_selectedCondition';
      }

      await ref.read(alertControllerProvider.notifier).createAlert(
        widget.symbol,
        value,
        finalCondition,
      );
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã tạo cảnh báo $_alertType cho ${widget.symbol}!"))
      );

    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

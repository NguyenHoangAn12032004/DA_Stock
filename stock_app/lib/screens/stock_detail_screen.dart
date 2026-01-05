import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/entities/order_entity.dart';
import '../presentation/widgets/stock_chart_widget.dart';
import '../presentation/widgets/order_book_widget.dart';
import '../presentation/providers/market_provider.dart';
import '../presentation/providers/order_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_prediction_card.dart';
import 'add_alert_bottom_sheet.dart';
import '../core/utils/stock_utils.dart';
import '../core/utils/currency_helper.dart'; 
import '../presentation/providers/settings_provider.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  String _selectedTimeframe = '3M';
  late String _currentSymbol;

  @override
  void initState() {
    super.initState();
    _currentSymbol = widget.symbol;
  }

  // Helper to get realtime price
  double? _getRealtimePrice() {
    final stockListAsync = ref.watch(stockListNotifierProvider);
    return stockListAsync.when(
      data: (stocks) {
        try {
           final exact = stocks.firstWhere((e) => e.symbol == _currentSymbol);
           return exact.price;
        } catch (_) {
           return null;
        }
      },
      loading: () => null,
      error: (_, __) => null,
    );
  }

  void _showOrderBottomSheet(BuildContext context, OrderSide side) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderBottomSheet(
        symbol: _currentSymbol,
        side: side,
        initialPrice: _getRealtimePrice() ?? 0.0,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    print("--- DEBUG: STOCK DETAIL SCREEN BUILD CALLED ---");
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8);
    final borderColor = isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111418).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentSymbol,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              'Spot Market',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                fontSize: 10,
              ),
            ),
          ],
        ),
        actions: [
           IconButton(
            icon: Icon(Icons.notifications_active_outlined, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
               showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => AddAlertBottomSheet(symbol: widget.symbol),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderStats(isDark),
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: StockChartWidget(
                      symbol: _currentSymbol,
                      timeframe: (_selectedTimeframe == '1D' && _selectedResolution.isNotEmpty)
                        ? '1D|$_selectedResolution'
                        : _selectedTimeframe,
                    ),
                  ),
                  _buildTimeframeSelector(theme, isDark),
                  const SizedBox(height: 16),
                  AiPredictionCard(
                    key: ValueKey(_currentSymbol),
                    symbol: _currentSymbol
                  ),
                  const SizedBox(height: 16),
                  OrderBookWidget(symbol: _currentSymbol),
                  const Divider(),
                  _buildOrderSection(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStats(bool isDark) {
    // Watch realtime data
    final stockListAsync = ref.watch(stockListNotifierProvider);
    final Locale locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
    
    return stockListAsync.when(
      data: (stocks) {
        // Find current symbol
        final stock = stocks.where((element) => element.symbol == _currentSymbol).firstOrNull;
        
        if (stock == null) {
          // If not in realtime list, maybe show loading or placeholder
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Loading realtime data..."),
          );
        }

        final isPositive = stock.changePercent >= 0;
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyHelper.format(stock.price, symbol: _currentSymbol, locale: locale),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                  ),

                  Row(
                    children: [
                      Text(
                        '${isPositive ? '+' : ''}${stock.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isPositive ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   // Format Volume as well? Usually compact is fine (1M, 200K).
                   Text('${locale.languageCode == 'vi' ? 'KL' : 'Vol'}: ${NumberFormat.compact().format(stock.volume)}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      error: (e, __) => Padding(padding: const EdgeInsets.all(16), child: Text("Error: $e")),
    );
  }

  Widget _buildOrderSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showOrderBottomSheet(context, OrderSide.buy),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text((ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'MUA' : 'BUY'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _showOrderBottomSheet(context, OrderSide.sell),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text((ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'BÁN' : 'SELL'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // State for intraday resolution
  String _selectedResolution = '30m'; // Default

  Widget _buildTimeframeSelector(ThemeData theme, bool isDark) {
    final timeframes = ['1D', '1W', '1M', '3M', '1Y', 'All'];
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: timeframes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tf = timeframes[index];
              final isSelected = tf == _selectedTimeframe;
              return ChoiceChip(
                label: Text(tf == '1D' && isSelected ? '1D ▾' : tf),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeframe = tf;
                      // Reset default resolution if switching to 1D
                      if (tf == '1D' && _selectedResolution.isEmpty) {
                         _selectedResolution = '30m';
                      }
                    });
                  }
                },
                backgroundColor: isDark ? const Color(0xFF1A2028) : Colors.white,
                selectedColor: AppColors.success,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppColors.success : (isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5)),
                  ),
                ),
                showCheckmark: false,
              );
            },
          ),
        ),
        if (_selectedTimeframe == '1D') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30, // Smaller chips for resolution
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['1m', '5m', '15m', '30m', '1H'].map((res) {
                final isResSelected = res == _selectedResolution;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(res, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    selected: isResSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedResolution = res;
                        });
                      }
                    },
                    backgroundColor: isDark ? Colors.transparent : Colors.grey[200],
                    selectedColor: AppColors.success.withOpacity(0.8),
                    labelStyle: TextStyle(
                      color: isResSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87),
                      fontWeight: isResSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isResSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ]
      ],
    );
  }
}


class _OrderBottomSheet extends ConsumerStatefulWidget {
  final String symbol;
  final OrderSide side;
  final double initialPrice;

  const _OrderBottomSheet({
    required this.symbol,
    required this.side,
    required this.initialPrice, // Always VND Base
  });

  @override
  ConsumerState<_OrderBottomSheet> createState() => _OrderBottomSheetState();
}

class _OrderBottomSheetState extends ConsumerState<_OrderBottomSheet> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  OrderType _orderType = OrderType.limit;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '100');
    _priceController = TextEditingController();
  }

  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
       final locale = ref.read(languageControllerProvider).valueOrNull ?? const Locale('en');
       final isVietnamese = locale.languageCode == 'vi';
       
       // Calculate Display Price
       double displayPrice = widget.initialPrice;
       if (!isVietnamese) {
           displayPrice = widget.initialPrice / CurrencyHelper.exchangeRate;
       }
       
       _priceController.text = _formatPrice(displayPrice, isVietnamese);
       _isInit = false;
    }
  }

  String _formatPrice(double price, bool isVietnamese) {
      if (isVietnamese) return price.toStringAsFixed(0);
      return price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ListView(
          controller: scrollController,
          shrinkWrap: true,
          children: [
              Text(
                '${widget.side == OrderSide.buy ? (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? "MUA" : "BUY") : (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? "BÁN" : "SELL")} ${widget.symbol}',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: widget.side == OrderSide.buy ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            
            // Order Type Toggle
            SegmentedButton<OrderType>(
              segments: [
                ButtonSegment(value: OrderType.limit, label: Text(ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'Lệnh Giới Hạn (LO)' : 'Limit Order (LO)')),
                ButtonSegment(value: OrderType.market, label: Text(ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'Lệnh Thị Trường (MP)' : 'Market Order (MP)')),
              ],
              selected: {_orderType},
              onSelectionChanged: (Set<OrderType> newSelection) {
                if (newSelection.isNotEmpty) {
                    setState(() {
                      _orderType = newSelection.first;
                      if (_orderType == OrderType.market) {
                        _priceController.text = "Market Price"; // Visual
                      } else {
                        // Reset to Initial Price (Converted)
                        final locale = ref.read(languageControllerProvider).valueOrNull ?? const Locale('en');
                        final isVietnamese = locale.languageCode == 'vi';
                        double displayPrice = widget.initialPrice;
                        if (!isVietnamese) displayPrice /= CurrencyHelper.exchangeRate;
                        
                        _priceController.text = _formatPrice(displayPrice, isVietnamese);
                      }
                    });
                  }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                     // Check if proper color usage
                     return AppColors.primary.withOpacity(0.2);
                  }
                  return Colors.transparent;
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Price Input
            Consumer(
              builder: (context, ref, _) {
                 final locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
                 final isVietnamese = locale.languageCode == 'vi';
                 final currencyLabel = isVietnamese ? 'VND' : 'USD';
                 final suffix = isVietnamese ? '₫' : '\$';
                 
                 return TextField(
                  controller: _priceController,
                  enabled: _orderType == OrderType.limit,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: isVietnamese ? 'Giá đặt (VND)' : 'Price Limit ($currencyLabel)',
                    border: const OutlineInputBorder(),
                    suffixText: suffix,
                  ),
                );
              }
            ),
            const SizedBox(height: 12),

            // Quantity Input
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'Khối lượng' : 'Quantity'),
                helperText: (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'Bội số của 100' : 'Multiple of 100'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Consumer(
                builder: (context, ref, child) {
                  final orderState = ref.watch(orderControllerProvider);
                  
                  return ElevatedButton(
                    onPressed: orderState.isLoading ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.side == OrderSide.buy ? AppColors.success : AppColors.danger,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: orderState.isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.side == OrderSide.buy 
                            ? (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'ĐẶT MUA' : 'PLACE BUY') 
                            : (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi' ? 'ĐẶT BÁN' : 'PLACE SELL'), 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)
                        ),
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    
    // Validate Price
    double px = 0.0;
    if (_orderType == OrderType.limit) {
      double inputPx = double.tryParse(_priceController.text) ?? 0.0;
      
      // CONVERT BACK TO VND BASE if needed
      final locale = ref.read(languageControllerProvider).valueOrNull ?? const Locale('en');
      final isVietnamese = locale.languageCode == 'vi';
      
      if (!isVietnamese) {
          // Input is USD, Convert to VND
          px = inputPx * CurrencyHelper.exchangeRate;
      } else {
          px = inputPx;
      }
      
    } else {
      px = widget.initialPrice; // Backend will recalculate for Market Order
    }
    
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khối lượng không hợp lệ')));
      return;
    }
    if (_orderType == OrderType.limit && px <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá không hợp lệ')));
      return;
    }

    final user = await ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập để giao dịch')));
       return;
    }

    await ref.read(orderControllerProvider.notifier).placeOrder(
      userId: user.id,
      symbol: widget.symbol,
      side: widget.side,
      quantity: qty,
      price: px,
      type: _orderType,
    );

    // Check result
    if (!mounted) return;
    
    final newState = ref.read(orderControllerProvider);
    if (newState.hasError) {
      final errorMsg = newState.error.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $errorMsg')));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đặt lệnh thành công!')));
    }
  }
}

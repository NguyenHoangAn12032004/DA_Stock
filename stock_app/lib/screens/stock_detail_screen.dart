import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/entities/order_entity.dart';
import '../presentation/widgets/stock_chart_widget.dart';
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
    final price = _getRealtimePrice() ?? 0.0;
    final quantityController = TextEditingController(text: '100');
    final priceController = TextEditingController(text: price.toString());
    
    // Get current user
    final authResult = ref.read(authRepositoryProvider).currentUser;
    // We need to resolve FutureOr. For MVP, assuming user is logged in if they are here.
    // Actually currentUser return Future<UserEntity?>. We should handle this better.
    // For now, let's just trigger the async check inside the sheet.

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                '${side == OrderSide.buy ? "Buy" : "Sell"} $_currentSymbol',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Consumer(
                  builder: (context, ref, child) {
                    final orderState = ref.watch(orderControllerProvider);
                    
                    return ElevatedButton(
                      onPressed: orderState.isLoading ? null : () async {
                        final qty = int.tryParse(quantityController.text) ?? 0;
                        final px = double.tryParse(priceController.text) ?? 0.0;
                        
                        if (qty <= 0 || px <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid quantity or price')));
                          return;
                        }

                        // Get User ID
                        final user = await ref.read(authRepositoryProvider).currentUser;
                        if (user == null) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to trade')));
                           return;
                        }

                        await ref.read(orderControllerProvider.notifier).placeOrder(
                          userId: user.id,
                          symbol: _currentSymbol,
                          side: side,
                          quantity: qty,
                          price: px,
                          type: OrderType.limit, // Default to limit for manually entered price
                        );

                        // Check result
                        // Since we can't easily check state change result here without a listener, 
                        // we'll listen to the provider in the parent or handle via callbacks.
                        // For MVP simplicity, check current state after await.
                        
                        final newState = ref.read(orderControllerProvider);
                        if (newState.hasError) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${newState.error}')));
                        } else {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Placed Successfully!')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: side == OrderSide.buy ? AppColors.success : AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: orderState.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(side == OrderSide.buy ? 'BUY' : 'SELL', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      timeframe: _selectedTimeframe,
                    ),
                  ),
                  _buildTimeframeSelector(theme, isDark),
                  const SizedBox(height: 16),
                  AiPredictionCard(
                    key: ValueKey(_currentSymbol),
                    symbol: _currentSymbol
                  ),
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
    final language = ref.watch(languageControllerProvider).valueOrNull ?? 'English';
    
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
                    CurrencyHelper.format(stock.price, symbol: _currentSymbol, language: language),
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
                   // Maybe just localize NumberFormat if really needed, but 'K'/'M' is universal enough.
                  Text('Vol: ${NumberFormat.compact().format(stock.volume)}', style: const TextStyle(fontSize: 12)),
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
              child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              child: const Text('Sell', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector(ThemeData theme, bool isDark) {
    final timeframes = ['1D', '1W', '1M', '3M', '1Y', 'All'];
    return SizedBox(
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
            label: Text(tf),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedTimeframe = tf;
                });
                // Provider automatically refetches
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
    );
  }
}


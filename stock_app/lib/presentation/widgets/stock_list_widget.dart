import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_entity.dart';
import '../providers/market_provider.dart';
import '../../screens/stock_detail_screen.dart'; // Ensure correct import path
// Note: If StockDetailScreen is in lib/screens/, path is correct relative to widgets if widget is in lib/presentation/widgets
// Actually, StockDetailScreen is likely in lib/screens, so ../../screens/stock_detail_screen.dart
import '../../screens/stock_detail_screen.dart'; 
import '../../theme/app_colors.dart';

class StockListWidget extends ConsumerWidget {
  const StockListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockIds = ref.watch(stockListNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Market Watch',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111418),
            ),
          ),
        ),
        const SizedBox(height: 12),
        stockIds.when(
          data: (stocks) {
            if (stocks.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('No data available'),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stocks.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final stock = stocks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildStockCard(context, stock, isDark),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Error loading market data: $error',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockCard(BuildContext context, StockEntity stock, bool isDark) {
    final isUp = stock.changePercent >= 0;
    final color = isUp ? AppColors.success : AppColors.danger;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(symbol: stock.symbol),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2633) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A3744) : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stock.symbol[0],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : const Color(0xFF111418),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF111418),
                      ),
                    ),
                    Text(
                      'Vol: ${stock.volume}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${stock.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111418),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stock.changePercent.abs().toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

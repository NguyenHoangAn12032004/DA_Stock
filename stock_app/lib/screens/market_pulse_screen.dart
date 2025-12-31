import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class MarketPulseScreen extends StatelessWidget {
  const MarketPulseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Mock data for market indices
    final List<Map<String, dynamic>> indices = [
      {
        'name': 'VN-Index',
        'exchange': 'HOSE',
        'price': 1240.50,
        'change': 6.20,
        'percent': 0.5,
        'isPositive': true
      },
      {
        'name': 'HNX-Index',
        'exchange': 'HNX',
        'price': 236.50,
        'change': -1.20,
        'percent': -0.5,
        'isPositive': false
      },
      {
        'name': 'UPCOM',
        'exchange': 'UPCOM',
        'price': 90.10,
        'change': 0.10,
        'percent': 0.1,
        'isPositive': true
      },
      {
        'name': 'VN30',
        'exchange': 'HOSE',
        'price': 1250.80,
        'change': 5.50,
        'percent': 0.44,
        'isPositive': true
      },
      {
        'name': 'HNX30',
        'exchange': 'HNX',
        'price': 480.20,
        'change': -2.10,
        'percent': -0.43,
        'isPositive': false
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Pulse'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: indices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = indices[index];
          return _buildMarketItem(theme, item);
        },
      ),
    );
  }

  Widget _buildMarketItem(ThemeData theme, Map<String, dynamic> item) {
    final isPositive = item['isPositive'] as bool;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A3441) : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.show_chart, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111418),
                  ),
                ),
                Text(
                  item['exchange'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9CABBA)
                        : const Color(0xFF637588),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item['price'].toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF111418),
                ),
              ),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: isPositive ? AppColors.success : AppColors.danger,
                    size: 20,
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${item['change']} (${item['percent']}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

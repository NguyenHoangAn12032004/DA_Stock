import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../theme/app_colors.dart';

// --- Provider ---
final marketIndicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = DioClient.instance.dio;
  try {
    final response = await dio.get('/api/market/indices');
    return List<Map<String, dynamic>>.from(response.data['data']);
  } catch (e) {
    throw Exception('Failed to load indices');
  }
});

class MarketPulseScreen extends ConsumerWidget {
  const MarketPulseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final indicesAsync = ref.watch(marketIndicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Pulse'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(marketIndicesProvider),
          )
        ],
      ),
      body: indicesAsync.when(
        data: (indices) {
          if (indices.isEmpty) {
            return const Center(child: Text("No data available"));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(marketIndicesProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: indices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildMarketItem(theme, indices[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildMarketItem(ThemeData theme, Map<String, dynamic> item) {
    final isPositive = (item['isPositive'] ?? false) as bool;
    final isDark = theme.brightness == Brightness.dark;
    
    // Safety handling for nulls
    final name = item['name'] ?? 'Index';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final change = (item['change'] as num?)?.toDouble() ?? 0.0;
    final percent = (item['percent'] as num?)?.toDouble() ?? 0.0;

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
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF111418),
                  ),
                ),
                Text(
                  'Global/Local', // We can improve this if we have exchange data
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
                price.toStringAsFixed(2),
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
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(2)} (${percent.toStringAsFixed(2)}%)',
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

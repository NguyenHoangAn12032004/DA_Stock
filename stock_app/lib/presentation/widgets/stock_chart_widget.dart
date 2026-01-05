import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chart_provider.dart';
import 'interactive_chart_widget.dart';

import '../../core/utils/currency_helper.dart';
import '../../presentation/providers/settings_provider.dart';

class StockChartWidget extends ConsumerWidget {
  final String symbol;
  final String timeframe;

  const StockChartWidget({
    super.key,
    required this.symbol,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartState = ref.watch(chartStateProvider(symbol, timeframe));

    return chartState.when(
      data: (data) {
        // Filter out bad data (zero values)
        final validData = data.where((e) => e.close > 0 && e.high > 0).toList();
        
        if (validData.isEmpty) {
          return const Center(child: Text('No valid chart data available'));
        }
        // CONVERSION LOGIC
        final locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
        final isVietnamese = locale.languageCode == 'vi';
        
        // Map data to new list with converted prices
        final displayData = validData.map((e) {
             if (isVietnamese) return e; 
             
             // Convert VND -> USD
             final rate = CurrencyHelper.exchangeRate;
             return e.copyWith(
                 open: e.open / rate,
                 close: e.close / rate,
                 high: e.high / rate,
                 low: e.low / rate,
             );
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(top: 8.0, right: 0),
          child: InteractiveChartWidget(
            datas: displayData,
            isLine: false, // Default to Candle
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}

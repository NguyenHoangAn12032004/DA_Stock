import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chart_provider.dart';
import 'interactive_chart_widget.dart';

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
        if (data.isEmpty) {
          return const Center(child: Text('No chart data available'));
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8.0, right: 0),
          child: InteractiveChartWidget(
            datas: data,
            isLine: false, // Default to Candle
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}

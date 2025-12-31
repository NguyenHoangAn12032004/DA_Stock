import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import '../../domain/entities/chart_data_entity.dart';

class InteractiveChartWidget extends StatelessWidget {
  final List<ChartDataEntity> datas;
  final bool isLine;

  const InteractiveChartWidget({
    Key? key,
    required this.datas,
    this.isLine = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (datas.isEmpty) {
      return const Center(child: Text("No Chart Data"));
    }

    // Map ChartDataEntity to Candle
    final candles = datas.map((e) {
      return Candle(
        date: e.time,
        open: e.open,
        high: e.high,
        low: e.low,
        close: e.close,
        volume: e.volume.toDouble(),
      );
    }).toList();
    
    // Sort candles by date descending as required by some libraries, 
    // but usually Candlesticks expects newest first? 
    // Let's check consistency. k_chart expected Old -> New.
    // candlesticks usually expects New -> Old (index 0 is newest).
    // ChartDataEntity is typically fetched via API which often returns Old -> New.
    // I should reverse it if needed.
    // KLineEntity was Old -> New (index 0 is oldest).
    // Candlesticks typically uses index 0 as most recent.
    // I will reverse the list to be safe OR check the library docs behavior.
    // Most financial charts: list[0] is newest.
    // My API returns historical data usually sorted by date ASC (Oldest first).
    // So I should reverse it.
    
    final reversedCandles = List<Candle>.from(candles.reversed);

    return Candlesticks(
      candles: reversedCandles,
      // Optional: Add indicators or actions here if supported
      // actions: [],
    );
  }
}

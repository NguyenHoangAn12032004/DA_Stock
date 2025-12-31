import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/stock_data.dart';
import '../theme/app_colors.dart';

class StockChart extends StatelessWidget {
  final List<StockData> data;
  final bool isPositive;

  const StockChart({
    super.key,
    required this.data,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    // Handle single data point case by duplicating it to form a flat line
    List<StockData> chartData = data;
    if (data.length == 1) {
      chartData = [data.first, data.first];
    }

    double minY = chartData.map((e) => e.close).reduce((a, b) => a < b ? a : b);
    double maxY = chartData.map((e) => e.close).reduce((a, b) => a > b ? a : b);
    double padding = (maxY - minY) * 0.1;
    
    if (padding == 0) padding = 1.0; // Prevent zero range if all values are equal

    // Using Primary Blue as per design for the main chart
    Color baseColor = AppColors.primary;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: chartData.length.toDouble() - 1,
        minY: minY - padding,
        maxY: maxY + padding,
        lineBarsData: [
          LineChartBarData(
            spots: chartData.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.close);
            }).toList(),
            isCurved: false,
            color: baseColor,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  baseColor.withOpacity(0.3),
                  baseColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  touchedSpot.y.toStringAsFixed(2),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
          ),
        ),
      ),
    );
  }
}

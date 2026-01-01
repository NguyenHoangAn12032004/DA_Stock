import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/chart_data_entity.dart';
import 'market_provider.dart';

part 'chart_provider.g.dart';

@riverpod
class ChartState extends _$ChartState {
  @override
  FutureOr<List<ChartDataEntity>> build(String symbol, String timeframe) async {
    final useCase = ref.watch(getStockHistoryUseCaseProvider);
    
    // Determine dates based on timeframe
    final now = DateTime.now();
    DateTime startDate;
    String resolution = '1D';

    // Handle composite timeframe: e.g., "1D|5m"
    String activeTimeframe = timeframe;
    String? customResolution;
    if (timeframe.contains('|')) {
      final parts = timeframe.split('|');
      activeTimeframe = parts[0];
      customResolution = parts[1];
    }

    switch (activeTimeframe) {
      case '1D':
        startDate = now.subtract(const Duration(days: 1));
        resolution = customResolution ?? '30m'; // Default Intraday to 30m
        break;
      case '1W':
        startDate = now.subtract(const Duration(days: 7));
        resolution = customResolution ?? '1H';
        break;
      case '1M':
        startDate = now.subtract(const Duration(days: 30));
        resolution = '1D';
        break;
      case '3M':
        startDate = now.subtract(const Duration(days: 90));
        resolution = '1D';
        break;
      case '1Y':
        startDate = now.subtract(const Duration(days: 365));
        resolution = '1D';
        break;
      case 'All':
        startDate = now.subtract(const Duration(days: 365 * 5));
        resolution = '1W';
        break;
      default:
        startDate = now.subtract(const Duration(days: 90));
        resolution = '1D';
    }

    // Format dates as YYYY-MM-DD
    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = now.toIso8601String().split('T')[0];

    final result = await useCase(symbol, startStr, endStr, resolution: resolution);

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }
}

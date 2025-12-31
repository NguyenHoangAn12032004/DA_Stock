import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/market_local_datasource.dart';
import '../../data/datasources/market_remote_datasource.dart';
import '../../data/repositories/market_repository_impl.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/repositories/market_repository.dart';
import '../../domain/usecases/get_realtime_quotes_usecase.dart';
import '../../domain/usecases/get_stock_history_usecase.dart';
import 'settings_provider.dart';

part 'market_provider.g.dart';

// --- DI ---

@riverpod
MarketRemoteDataSource marketRemoteDataSource(MarketRemoteDataSourceRef ref) {
  return MarketRemoteDataSourceImpl(DioClient.instance);
}

@riverpod
MarketLocalDataSource marketLocalDataSource(MarketLocalDataSourceRef ref) {
  return MarketLocalDataSourceImpl();
}

@riverpod
MarketRepository marketRepository(MarketRepositoryRef ref) {
  return MarketRepositoryImpl(
    ref.watch(marketRemoteDataSourceProvider),
    ref.watch(marketLocalDataSourceProvider),
  );
}

@riverpod
GetRealtimeQuotesUseCase getRealtimeQuotesUseCase(GetRealtimeQuotesUseCaseRef ref) {
  return GetRealtimeQuotesUseCase(ref.watch(marketRepositoryProvider));
}

@riverpod
GetStockHistoryUseCase getStockHistoryUseCase(GetStockHistoryUseCaseRef ref) {
  return GetStockHistoryUseCase(ref.watch(marketRepositoryProvider));
}

// --- Logic ---

@riverpod
class MarketData extends _$MarketData {
  @override
  Stream<List<StockEntity>> build() {
    final repo = ref.watch(marketRepositoryProvider);
    
    // 1. Connect WS when this provider is listened to
    repo.connectToMarketStream();
    
    // 2. Disconnect when disposed
    ref.onDispose(() {
      repo.disconnectFromMarketStream();
    });

    // 3. Return the stream
    // Combine initial fetch with stream?
    // Actually, simple Stream is internal. 
    // We should probably merge initial fetch result into the stream or just rely on stream updates.
    
    return repo.marketDataStream;
  }
}

// Alternatively, we can use a simpler Notifier that manages the list state manually
// to handle the "Initial Fetch" + "Stream Updates" merging logic better.

@riverpod
class StockListNotifier extends _$StockListNotifier {
  Timer? _pollingTimer;

  @override
  FutureOr<List<StockEntity>> build() async {
    final refreshRate = ref.watch(dataRefreshControllerProvider).valueOrNull ?? 'Auto';
    final repo = ref.watch(marketRepositoryProvider);
    
    // Initial Fetch
    List<StockEntity> currentList = await _fetchData();

    // Cleanup previous subscriptions/timers
    _pollingTimer?.cancel();
    // repo.disconnectFromMarketStream(); // Handled by simple stream subscription cancel? 
    // Actually repo connects on demand. We should explicitly handle stream subscription.

    if (refreshRate == 'Auto') {
      // Stream Mode
      await repo.connectToMarketStream();
      final subscription = repo.marketDataStream.listen((updates) {
        currentList = _mergeUpdates(currentList, updates);
        state = AsyncData(currentList);
      });
      
      ref.onDispose(() {
        subscription.cancel();
        repo.disconnectFromMarketStream();
      });
    } else if (refreshRate == 'Manual') {
      // Manual Mode: Just initial fetch. No stream, no timer.
      // User must pull-to-refresh (to be implemented in UI if not exists)
    } else {
      // Polling Mode
      int seconds = 60;
      if (refreshRate == '5 Minutes') seconds = 300;
      
      _pollingTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
        final newData = await _fetchData();
        currentList = newData; // Full replace or merge? Fetch returns full list usually.
        state = AsyncData(currentList);
      });

      ref.onDispose(() {
        _pollingTimer?.cancel();
      });
    }

    return currentList;
  }

  Future<List<StockEntity>> _fetchData() async {
     final result = await ref.read(getRealtimeQuotesUseCaseProvider).call([
      "HPG", "VCB", "FPT", "AAPL", "BTC-USD", "GOOG"
    ]);
    return result.fold((l) => [], (r) => r);
  }

  List<StockEntity> _mergeUpdates(List<StockEntity> current, List<StockEntity> updates) {
      final Map<String, StockEntity> stockMap = {
        for (var s in current) s.symbol: s
      };
      for (var update in updates) {
        stockMap[update.symbol] = update;
      }
      return stockMap.values.toList();
  }
}

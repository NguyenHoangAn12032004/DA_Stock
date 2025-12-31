import 'package:hive_flutter/hive_flutter.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/stock_entity.dart';


abstract class MarketLocalDataSource {
  Future<List<StockEntity>> getLastKnownQuotes();
  Future<void> cacheQuotes(List<StockEntity> stocks);
}

class MarketLocalDataSourceImpl implements MarketLocalDataSource {
  static const String boxName = 'market_quotes';

  @override
  Future<List<StockEntity>> getLastKnownQuotes() async {
    try {
      final box = await Hive.openBox(boxName);
      // We assume we store a list or individual keys. 
      // Individual keys are better for updates.
      List<StockEntity> stocks = [];
      for (var key in box.keys) {
         final data = box.get(key);
         // Transform stored map/object back to Entity
         // Assuming we store as Map for simplicity if not using Adapters yet
         if (data is Map) {
            stocks.add(StockEntity(
              symbol: data['symbol'],
              price: data['price'],
              changePercent: data['changePercent'],
              volume: data['volume'],
            ));
         }
      }
      return stocks;
    } catch (e) {
      throw CacheFailure();
    }
  }

  @override
  Future<void> cacheQuotes(List<StockEntity> stocks) async {
    try {
      final box = await Hive.openBox(boxName);
      for (var stock in stocks) {
        await box.put(stock.symbol, {
          'symbol': stock.symbol,
          'price': stock.price,
          'changePercent': stock.changePercent,
          'volume': stock.volume,
        });
      }
    } catch (e) {
      throw CacheFailure();
    }
  }
}

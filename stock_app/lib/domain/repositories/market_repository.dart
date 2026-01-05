import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/stock_entity.dart';
import '../entities/chart_data_entity.dart';
import '../entities/order_book_entity.dart';

abstract class MarketRepository {
  /// Fetches real-time market data for a list of symbols.
  /// This can be a one-time fetch or a polling mechanism wrapped in a Stream elsewhere.
  /// For now, we define a Future for explicit fetching.
  Future<Either<Failure, List<StockEntity>>> getRealtimeQuotes(List<String> symbols);
  
  /// Stream of real-time updates (via WebSocket or Polling)
  Stream<List<StockEntity>> get marketDataStream;

  /// Connect/Disconnect WebSocket
  Future<void> connectToMarketStream();
  Future<void> disconnectFromMarketStream();
  
  /// Fetches historical data for charts
  Future<Either<Failure, List<ChartDataEntity>>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D'});

  /// Fetches Order Book (Depth)
  Future<Either<Failure, OrderBookEntity>> getOrderBook(String symbol);
}

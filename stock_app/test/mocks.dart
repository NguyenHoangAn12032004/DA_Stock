import 'dart:async';
import 'package:stock_app/data/datasources/market_remote_datasource.dart';
import 'package:stock_app/domain/entities/stock_entity.dart';
import 'package:stock_app/domain/entities/chart_data_entity.dart';
import 'package:stock_app/domain/entities/order_book_entity.dart';

class FakeMarketRemoteDataSource implements MarketRemoteDataSource {
  @override
  Future<List<StockEntity>> getInitialQuotes(List<String> symbols) async {
    // Return dummy data
    return [
      const StockEntity(symbol: 'HPG', price: 20500, changePercent: 1.2, volume: 100000),
      const StockEntity(symbol: 'VCB', price: 85000, changePercent: -0.5, volume: 50000),
    ];
  }

  @override
  Stream<List<StockEntity>> get marketDataStream => Stream.value([]);

  @override
  Future<void> connectStream() async {}

  @override
  Future<void> disconnectStream() async {}

  @override
  Future<List<ChartDataEntity>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D'}) async {
    return [];
  }

  @override
  Future<OrderBookEntity> getOrderBook(String symbol) async {
    return OrderBookEntity(symbol: symbol, bids: [], asks: []);
  }
}

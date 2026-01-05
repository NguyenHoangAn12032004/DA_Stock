import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/chart_data_entity.dart';
import '../../domain/entities/order_book_entity.dart';


abstract class MarketRemoteDataSource {
  Future<List<StockEntity>> getInitialQuotes(List<String> symbols);
  Stream<List<StockEntity>> get marketDataStream;
  Future<void> connectStream();
  Future<void> disconnectStream();
  Future<List<ChartDataEntity>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D'});
  Future<OrderBookEntity> getOrderBook(String symbol);
}

class MarketRemoteDataSourceImpl implements MarketRemoteDataSource {
  final DioClient _dioClient;
  WebSocketChannel? _channel;
  final StreamController<List<StockEntity>> _streamController = StreamController.broadcast();

  // Cache latest values to emit updates as a list
  final Map<String, StockEntity> _latestStocks = {};

  MarketRemoteDataSourceImpl(this._dioClient);

  @override
  Future<OrderBookEntity> getOrderBook(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/api/orderbook/$symbol');
      
      if (response.statusCode == 200) {
        final data = response.data;
        // API returns { "bids": [...], "asks": [...] }
        
        final bids = (data['bids'] as List)
            .map((e) => OrderBookEntry.fromJson(e))
            .toList();
            
        final asks = (data['asks'] as List)
            .map((e) => OrderBookEntry.fromJson(e))
            .toList();
            
        return OrderBookEntity(
          symbol: symbol,
          bids: bids,
          asks: asks,
        );
      } else {
        throw ServerFailure('Failed to fetch order book');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<StockEntity>> getInitialQuotes(List<String> symbols) async {
    List<StockEntity> results = [];
    
    // For MVP, since we don't have a bulk current-price API, 
    // we fetch 1-day history for each symbol to get the latest close price.
    // This is not efficient for many stocks but acceptable for < 10 stocks in MVP.
    
    // We can also try to infer from previous implementation.
    // Let's iterate.
    
    // Use efficient Batch API (Redis Cache)
    try {
      final response = await _dioClient.dio.post(
        '/api/stock/batch_quotes',
        data: {'symbols': symbols},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        for (var item in data) {
           // Item: { "symbol": "HPG", "price": 28000, "change_percent": 1.2, "volume": ... }
           if (item['symbol'] != null) {
              final entity = StockEntity(
                 symbol: item['symbol'],
                 price: (item['price'] as num?)?.toDouble() ?? 0.0,
                 changePercent: (item['change_percent'] as num?)?.toDouble() ?? 0.0,
                 volume: (item['volume'] as num?)?.toInt() ?? 0,
              );
              results.add(entity);
              _latestStocks[entity.symbol] = entity;
           }
        }
      }
    } catch (e) {
      print("Batch Quotes Error: $e");
      // Fallback or return empty
    }
    return results;
  }

  @override
  Stream<List<StockEntity>> get marketDataStream => _streamController.stream;

  @override
  Future<void> connectStream() async {
    if (_channel != null) return;

    // Determine WS URL based on BaseOptions or AppConstants
    // For now hardcode or derive. 
    // dioClient.dio.options.baseUrl is 'http://127.0.0.1:8000' or similar.
    // We need to replace http with ws.
    
    // const wsUrl = 'ws://127.0.0.1:8000/ws/stocks'; // For Windows
    // const wsUrl = 'ws://10.0.2.2:8000/ws/stocks'; // For Android Emulator
    
    // Simple platform check (requires dart:io)
    // Or just try 10.0.2.2 for now since user is on Android Emulator
    String wsUrl = 'ws://10.0.2.2:8000/ws/stocks'; 
    try {
        if (Platform.isWindows) {
             wsUrl = 'ws://127.0.0.1:8000/ws/stocks';
        }
    } catch(e) {} // Platform.isWindows might throw on web? No, but safe to wrap.

    try {
      print("Connecting WS to: $wsUrl");
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (message) {
          try {
            // Expected message: JSON String of single stock update
            // e.g. {"symbol": "HPG", "price": ...}
            final data = jsonDecode(message);
            
            // Validate fields
            if (data['symbol'] != null) {
               final entity = StockEntity(
                 symbol: data['symbol'],
                 price: (data['price'] as num).toDouble(),
                 changePercent: (data['change_percent'] as num).toDouble(),
                 volume: (data['volume'] as num).toInt(),
               );
               
               _latestStocks[entity.symbol] = entity;
               
               // Emit updated list
               _streamController.add(_latestStocks.values.toList());
            }
          } catch (e) {
            print("WS Parse Error: $e");
          }
        },
        onError: (error) {
          print("WS Error: $error");
          // Reconnect logic could go here
        },
        onDone: () {
          print("WS Closed");
          _channel = null;
        },
      );
    } catch (e) {
      throw ServerFailure("Failed to connect to WebSocket: $e");
    }
  }

  @override
  Future<void> disconnectStream() async {
    await _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  @override
  Future<List<ChartDataEntity>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D'}) async {
    try {
      final response = await _dioClient.dio.get(
        '/api/history',
        queryParameters: {
          'symbol': symbol,
          'start_date': startDate,
          'end_date': endDate,
          'resolution': resolution
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        return data.map((json) {
          // Flatten mapping
          return ChartDataEntity(
            time: DateTime.parse(json['time']), // Ensure format is parseable or use DateFormat
            open: (json['open'] as num?)?.toDouble() ?? 0.0,
            high: (json['high'] as num?)?.toDouble() ?? 0.0,
            low: (json['low'] as num?)?.toDouble() ?? 0.0,
            close: (json['close'] as num?)?.toDouble() ?? 0.0,
            volume: (json['volume'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      } else {
        throw ServerFailure('Failed to fetch history: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

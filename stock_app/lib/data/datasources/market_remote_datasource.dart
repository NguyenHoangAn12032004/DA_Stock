import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/chart_data_entity.dart';


abstract class MarketRemoteDataSource {
  Future<List<StockEntity>> getInitialQuotes(List<String> symbols);
  Stream<List<StockEntity>> get marketDataStream;
  Future<void> connectStream();
  Future<void> disconnectStream();
  Future<List<ChartDataEntity>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D'});
}

class MarketRemoteDataSourceImpl implements MarketRemoteDataSource {
  final DioClient _dioClient;
  WebSocketChannel? _channel;
  final StreamController<List<StockEntity>> _streamController = StreamController.broadcast();

  // Cache latest values to emit updates as a list
  final Map<String, StockEntity> _latestStocks = {};

  MarketRemoteDataSourceImpl(this._dioClient);

  @override
  Future<List<StockEntity>> getInitialQuotes(List<String> symbols) async {
    List<StockEntity> results = [];
    
    // For MVP, since we don't have a bulk current-price API, 
    // we fetch 1-day history for each symbol to get the latest close price.
    // This is not efficient for many stocks but acceptable for < 10 stocks in MVP.
    
    // We can also try to infer from previous implementation.
    // Let's iterate.
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    // Start date = 3 days ago to be safe (weekends)
    final startDate = DateTime.now().subtract(const Duration(days: 5)).toIso8601String().split('T')[0];

    // Note: Concurrency might be limited by server. Run in sequence or small batches.
    for (var symbol in symbols) {
      try {
        final response = await _dioClient.dio.get(
          '/api/history',
          queryParameters: {
            'symbol': symbol,
            'start_date': startDate,
            'end_date': today,
            'resolution': '1D'
          },
        );
        
        if (response.statusCode == 200) {
          final data = response.data['data'] as List;
          if (data.isNotEmpty) {
            final lastRecord = data.last;
            
            double changePercent = 0.0;
            if (data.length >= 2) {
              final prevRecord = data[data.length - 2];
              final double close = (lastRecord['close'] as num).toDouble();
              final double prevClose = (prevRecord['close'] as num).toDouble();
              
              if (prevClose > 0) {
                changePercent = ((close - prevClose) / prevClose) * 100;
              }
            }
            
            // Map to StockEntity
            // backend 'data' items: { "time": "...", "open": ..., "close": ... }
            final entity = StockEntity(
              symbol: symbol,
              price: (lastRecord['close'] as num).toDouble(),
              changePercent: changePercent,
              volume: (lastRecord['volume'] as num).toInt(),
            );
            results.add(entity);
            _latestStocks[symbol] = entity;
          }
        }
      } catch (e) {
        // Ignore errors for individual stocks to return partial list
        print("Error fetching initial quote for $symbol: $e");
      }
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
            open: (json['open'] as num).toDouble(),
            high: (json['high'] as num).toDouble(),
            low: (json['low'] as num).toDouble(),
            close: (json['close'] as num).toDouble(),
            volume: (json['volume'] as num).toInt(),
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

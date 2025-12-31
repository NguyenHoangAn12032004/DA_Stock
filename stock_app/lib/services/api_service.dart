import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_data.dart'; // Ensure this model exists, referenced in stock_detail_screen
import '../models/company_overview.dart'; // Ensure this model exists
import '../models/signal.dart';

class ApiService {
  // Legacy Stock Server (Main Data)
  static const String baseUrl = 'http://10.0.2.2:8000'; 
  
  // New AI/RL Server
  static const String aiBaseUrl = 'http://10.0.2.2:8001'; 

  // --- Legacy Endpoints (restored) ---

  Future<List<StockData>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D', String? period}) async {
    final queryParams = {
      'symbol': symbol,
      'start_date': startDate,
      'end_date': endDate,
      'resolution': resolution,
    };
    if (period != null) {
      queryParams['period'] = period;
    }

    final url = Uri.parse('$baseUrl/api/history').replace(queryParameters: queryParams);
    
    // print('GET $url'); 

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      // Expected format from stock_server: { "symbol": "...", "source": "...", "data": [...] }
      final List<dynamic> data = jsonResponse['data'];
      return data.map((json) => StockData.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load stock history');
    }
  }

  Future<CompanyOverview?> getCompanyOverview(String symbol) async {
    final url = Uri.parse('$baseUrl/api/company/overview').replace(queryParameters: {'symbol': symbol});
    
    try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          // Expected format: { "data": [ { ... } ] }
          final List<dynamic> data = jsonResponse['data'];
          if (data.isNotEmpty) {
             return CompanyOverview.fromJson(data[0]);
          }
        }
    } catch (e) {
        print("Error fetching overview: $e");
    }
    return null;
  }

  // --- New AI Endpoints (Port 8001) ---

  Future<Map<String, Signal>> fetchSignals() async {
    final url = Uri.parse('$aiBaseUrl/rl/predict').replace(queryParameters: {
      'config': 'configs/rl_enhanced.yaml',
      'model': 'models/ppo_trading.zip',
    });

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final signalsData = data['signals'] as Map<String, dynamic>;
        
        Map<String, Signal> signals = {};
        signalsData.forEach((ticker, signalJson) {
           signals[ticker] = Signal.fromJson(ticker, signalJson);
        });
        return signals;
      } else {
        throw Exception('Failed to load signals: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching signals: $e');
    }
  }

  Future<Map<String, dynamic>> chat(String symbol, String message) async {
    final url = Uri.parse('$aiBaseUrl/chat');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'symbol': symbol,
        'message': message,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to chat');
    }
  }

  // --- Order Endpoints (Legacy Server) ---

  Future<Map<String, dynamic>> placeOrder(String userId, String symbol, String side, int quantity, double price, {String orderType = 'limit'}) async {
    final url = Uri.parse('$baseUrl/api/orders');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'symbol': symbol,
        'side': side,
        'quantity': quantity,
        'price': price,
        'order_type': orderType,
      }),
    );

    if (response.statusCode == 200) {
      // Server returns { "status": "success", "message": "...", "data": { ... } }
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to place order: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getOrders(String userId) async {
    final url = Uri.parse('$baseUrl/api/orders/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      // Server returns { "data": [ { ... }, { ... } ] }
      final List<dynamic> ordersList = jsonResponse['data'];
      return ordersList.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch orders');
    }
  }

  Future<Map<String, dynamic>> fetchOrderBook(String symbol) async {
    try {
      final url = Uri.parse('$baseUrl/api/orderbook/$symbol');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'bids': [], 'asks': []};
      }
    } catch (e) {
      print('Error fetching order book: $e');
      return {'bids': [], 'asks': []};
    }
  }

  // --- Alerts Endpoints ---

  Future<Map<String, dynamic>> createAlert(String userId, String symbol, String condition, double value, {String type = 'Price'}) async {
    final url = Uri.parse('$baseUrl/api/alerts');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'symbol': symbol,
        'condition': condition,
        'value': value,
        'type': type,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create alert');
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts(String userId) async {
    final url = Uri.parse('$baseUrl/api/alerts/$userId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final List<dynamic> list = jsonResponse['data'];
      return list.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  Future<void> deleteAlert(String userId, String alertId) async {
    final url = Uri.parse('$baseUrl/api/alerts/$userId/$alertId');
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete alert');
    }
  }
}

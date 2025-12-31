import 'package:dio/dio.dart';

class ForexService {
  final Dio _dio = Dio();
  
  // Free API: open.er-api.com
  // Backup: api.exchangerate-api.com
  static const String _baseUrl = 'https://open.er-api.com/v6/latest/USD';

  Future<double?> getUsdVndRate() async {
    try {
      final response = await _dio.get(_baseUrl);
      if (response.statusCode == 200) {
        final rates = response.data['rates'];
        if (rates != null && rates['VND'] != null) {
          // Add a small buffer/spread if needed, or return raw.
          // User asked for "standard market price". Bank rate is usually lower than Black Market.
          // This API usually provides mid-market rates.
          return (rates['VND'] as num).toDouble();
        }
      }
      return null;
    } catch (e) {
      print('Forex Error: $e');
      return null;
    }
  }
}

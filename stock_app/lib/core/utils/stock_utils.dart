import 'package:intl/intl.dart';

class StockUtils {
  static bool isVnStock(String symbol) {
    // Basic heuristic: 3 uppercase letters is likely VN stock (e.g., HPG, VCB).
    // Everything else (GOOG, BTC-USD, Crypto) is international.
    return symbol.length == 3 && 
           !symbol.contains('-') && 
           !symbol.contains(RegExp(r'[0-9]')) &&
           symbol == symbol.toUpperCase();
  }

  static String formatPrice(String symbol, double price) {
    if (isVnStock(symbol)) {
      // VN Stock: Format as 26.500 ₫
      // Ensure we treat small values (e.g. 26.5) as thousands if necessary?
      // No, let's assume backend sends correct raw value 26500.
      // If backend sends 26.5, we will fix backend.
      return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(price);
    } else {
      // US/Crypto: Format as $313.51
      return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(price);
    }
  }
}

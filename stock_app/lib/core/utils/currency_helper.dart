import 'package:intl/intl.dart';

class CurrencyHelper {
  static double exchangeRate = 27000; // Default fallback

  static void updateExchangeRate(double rate) {
    if (rate > 0) {
      exchangeRate = rate;
      print("Updated Exchange Rate to: $rate");
    }
  }

  static bool isForeign(String symbol) {
    if (symbol.isEmpty) return false;
    // Heuristic for MVP:
    // Crypto pairs like BTC-USD
    if (symbol.contains('-')) return true; 
    // US Stocks often > 3 chars (GOOG, AAPL, TSLA)
    if (symbol.length > 3) return true;
    // Known short US stocks/Indices could be added here
    if (['F', 'T', 'C', 'CS'].contains(symbol)) return true;
    
    // Default assumption: 3 letters = VN Stock (HPG, VNM, VIC)
    return false; 
  }

  static String format(double price, {required String symbol, required String language}) {
    final isVietnamese = language == 'Vietnamese';
    final foreign = isForeign(symbol);

    double finalPrice = price;
    String currencySymbol = isVietnamese ? '₫' : '\$';
    String locale = isVietnamese ? 'vi_VN' : 'en_US';
    int decimalDigits = 2; // Default

    if (isVietnamese) {
        // Mode: VIETNAMESE (Show everything in VND)
        if (foreign) {
            // USD -> VND
            finalPrice = price * exchangeRate;
        }
        // VN Stock is already in VND
        decimalDigits = 0; // VND usually no decimals
    } else {
        // Mode: ENGLISH (Show everything in USD)
        if (!foreign) {
            // VND -> USD
            finalPrice = price / exchangeRate;
            decimalDigits = 2;
        }
        // US Stock is already in USD
    }

    // NumberFormat handles the formatting (commas vs dots)
    return NumberFormat.currency(
      locale: locale, 
      symbol: currencySymbol,
      decimalDigits: decimalDigits
    ).format(finalPrice);
  }
  
  // Helper to get raw converted value (for sorting or calcs)
  static double convert(double price, {required String symbol, required String language}) {
    final isVietnamese = language == 'Vietnamese';
    final foreign = isForeign(symbol);
    
    if (isVietnamese && foreign) {
      return price * exchangeRate;
    } 
    if (!isVietnamese && !foreign) {
      return price / exchangeRate;
    }
    return price;
  }
}

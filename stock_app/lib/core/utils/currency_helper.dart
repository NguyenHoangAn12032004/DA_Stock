import 'dart:ui';
import 'package:intl/intl.dart';

class CurrencyHelper {
  static double exchangeRate = 25450; // Synced with Backend default

  static void updateExchangeRate(double rate) {
    if (rate > 0) {
      exchangeRate = rate;
      print("Updated Exchange Rate to: $rate");
    }
  }

  // Helper to determine if symbol is foreign (Just for potential UI tweaks, not value conversion anymore)
  static bool isForeign(String symbol) {
    if (symbol.isEmpty) return false;
    if (symbol.contains('-')) return true; 
    if (symbol.length > 3) return true;
    if (['F', 'T', 'C', 'CS'].contains(symbol)) return true;
    return false; 
  }

  /// Formats a price (assumed to be in VND Base) to the target locale.
  static String format(double priceVnd, {required String symbol, required Locale locale}) {
    final isVietnamese = locale.languageCode == 'vi';

    double finalPrice;
    String currencySymbol;
    String localeCode;
    int decimalDigits;

    if (isVietnamese) {
        // Mode: VIETNAMESE -> Show VND
        finalPrice = priceVnd;
        currencySymbol = '₫';
        localeCode = 'vi_VN';
        decimalDigits = 0; 
    } else {
        // Mode: ENGLISH -> Convert VND to USD
        finalPrice = priceVnd / exchangeRate;
        currencySymbol = '\$';
        localeCode = 'en_US';
        decimalDigits = 2;
    }

    return NumberFormat.currency(
      locale: localeCode, 
      symbol: currencySymbol,
      decimalDigits: decimalDigits
    ).format(finalPrice);
  }
  
  // Helper to get raw converted value (for sorting or calculations in target currency)
  static double convert(double priceVnd, {required String symbol, required Locale locale}) {
    final isVietnamese = locale.languageCode == 'vi';
    
    if (isVietnamese) {
      return priceVnd;
    } else {
      return priceVnd / exchangeRate;
    }
  }
}

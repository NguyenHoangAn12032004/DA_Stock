import '../../domain/entities/stock_entity.dart';

class StockDataModel extends StockEntity {
  const StockDataModel({
    required super.symbol,
    required super.price,
    required super.change,
    required super.changePercent,
  });

  factory StockDataModel.fromJson(Map<String, dynamic> json) {
    return StockDataModel(
      symbol: json['symbol'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      change: (json['change'] ?? 0.0).toDouble(),
      changePercent: (json['change_percent'] ?? 0.0).toDouble(),
    );
  }
}

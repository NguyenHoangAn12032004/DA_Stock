import 'package:equatable/equatable.dart';

class StockEntity extends Equatable {
  final String symbol;
  final double price;
  final double changePercent;
  final int volume;
  final String? name; // Optional name if available

  const StockEntity({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.volume,
    this.name,
  });

  @override
  List<Object?> get props => [symbol, price, changePercent, volume, name];
}

import 'package:equatable/equatable.dart';

class HoldingEntity extends Equatable {
  final String symbol;
  final int quantity;
  final double averagePrice;

  const HoldingEntity({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });

  @override
  List<Object?> get props => [symbol, quantity, averagePrice];

  double get totalValue => quantity * averagePrice; 
  // Note: This is cost basis. Realtime value requires current price from MarketProvider.
}

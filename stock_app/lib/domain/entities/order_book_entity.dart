import 'package:equatable/equatable.dart';

class OrderBookEntry extends Equatable {
  final double price;
  final int quantity;

  const OrderBookEntry({required this.price, required this.quantity});

  @override
  List<Object?> get props => [price, quantity];

  factory OrderBookEntry.fromJson(Map<String, dynamic> json) {
    return OrderBookEntry(
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
    );
  }
}

class OrderBookEntity extends Equatable {
  final String symbol;
  final List<OrderBookEntry> bids;
  final List<OrderBookEntry> asks;

  const OrderBookEntity({
    required this.symbol,
    required this.bids,
    required this.asks,
  });

  @override
  List<Object?> get props => [symbol, bids, asks];
  
  // Empty state
  static const empty = OrderBookEntity(symbol: '', bids: [], asks: []);
}

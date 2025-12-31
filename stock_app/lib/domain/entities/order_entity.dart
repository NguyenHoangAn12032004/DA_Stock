import 'package:equatable/equatable.dart';

enum OrderSide { buy, sell }
enum OrderType { market, limit }
enum OrderStatus { pending, matched, canceled }

class OrderEntity extends Equatable {
  final String? id;
  final String userId;
  final String symbol;
  final OrderSide side;
  final int quantity;
  final double price;
  final OrderType type;
  final OrderStatus status;
  final int timestamp;

  const OrderEntity({
    this.id,
    required this.userId,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    this.type = OrderType.limit,
    this.status = OrderStatus.pending,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, userId, symbol, side, quantity, price, type, status, timestamp];
}

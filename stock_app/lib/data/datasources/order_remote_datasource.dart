import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Future<OrderEntity> placeOrder(OrderEntity order);
  Future<List<OrderEntity>> getOrders(String userId);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final DioClient _dioClient;

  OrderRemoteDataSourceImpl(this._dioClient);

  @override
  Future<OrderEntity> placeOrder(OrderEntity order) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/orders',
        data: {
          'user_id': order.userId,
          'symbol': order.symbol,
          'side': order.side.name, // "buy" or "sell"
          'quantity': order.quantity,
          'price': order.price,
          'order_type': order.type.name, // "market" or "limit"
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return OrderEntity(
          id: data['order_id'],
          userId: data['user_id'],
          symbol: data['symbol'],
          side: data['side'] == 'buy' ? OrderSide.buy : OrderSide.sell,
          quantity: data['quantity'],
          price: (data['price'] as num).toDouble(),
          type: data['order_type'] == 'market' ? OrderType.market : OrderType.limit,
          status: OrderStatus.pending, // Default for now
          timestamp: data['timestamp'],
        );
      } else {
        throw ServerFailure('Failed to place order: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<OrderEntity>> getOrders(String userId) async {
    try {
      final response = await _dioClient.dio.get('/api/orders/$userId');

      if (response.statusCode == 200) {
        final List list = response.data['data'];
        return list.map((data) {
          return OrderEntity(
            id: data['order_id'],
            userId: data['user_id'],
            symbol: data['symbol'],
            side: data['side'] == 'buy' ? OrderSide.buy : OrderSide.sell,
            quantity: int.tryParse(data['quantity'].toString()) ?? 0,
            price: (data['price'] as num).toDouble(),
            type: data['order_type'] == 'market' ? OrderType.market : OrderType.limit,
            status: data['status'] == 'matched' ? OrderStatus.matched : OrderStatus.pending,
            timestamp: int.tryParse(data['timestamp'].toString()) ?? 0,
          );
        }).toList();
      } else {
        throw ServerFailure('Failed to fetch orders');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

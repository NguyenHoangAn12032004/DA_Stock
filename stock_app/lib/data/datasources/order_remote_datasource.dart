import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/order_entity.dart';

abstract class OrderRemoteDataSource {
  Future<OrderEntity> placeOrder(OrderEntity order);
  Future<List<OrderEntity>> getOrders(String userId);
  Future<void> cancelOrder(String userId, String orderId);
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
        // Backend returns: {"status": "success", "order_id": "...", "message": "..."}
        // It does NOT return the full order object in 'data'. 
        // We must construct the returned Entity from the Request + Response ID.
        final responseData = response.data; 
        
        return OrderEntity(
          id: responseData['order_id'],
          userId: order.userId,
          symbol: order.symbol,
          side: order.side,
          quantity: order.quantity,
          price: order.price,
          type: order.type,
          status: OrderStatus.pending,
          timestamp: DateTime.now().millisecondsSinceEpoch, // Use current client time as fallback, or parsed if available
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
            id: data['id'] ?? data['order_id'], // Handle potential inconsistencies
            userId: data['user_id'] ?? userId,
            symbol: data['symbol'],
            side: data['side'].toString().trim().toLowerCase() == 'buy' ? OrderSide.buy : OrderSide.sell,
            quantity: int.tryParse(data['quantity'].toString()) ?? 0,
            price: double.tryParse(data['price'].toString()) ?? 0.0,
            type: data['order_type'].toString().toLowerCase() == 'market' ? OrderType.market : OrderType.limit,
            status: data['status'] == 'matched' || data['status'] == 'filled' ? OrderStatus.matched : (data['status'] == 'cancelled' ? OrderStatus.canceled : OrderStatus.pending),
            // Fix: Backend sends seconds (float), Frontend needs Milliseconds (int)
            timestamp: ((double.tryParse(data['timestamp'].toString()) ?? 0) * 1000).toInt(),
          );
        }).toList();
      } else {
        throw ServerFailure('Failed to fetch orders');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
    @override
  Future<void> cancelOrder(String userId, String orderId) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/orders/cancel',
        data: {'user_id': userId, 'order_id': orderId},
      );
      if (response.statusCode != 200) {
         throw ServerFailure('Failed to cancel order');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

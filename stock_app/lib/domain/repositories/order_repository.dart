import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<Either<Failure, OrderEntity>> placeOrder(OrderEntity order);
  Future<Either<Failure, List<OrderEntity>>> getOrders(String userId);
  Future<Either<Failure, void>> cancelOrder(String userId, String orderId);
}

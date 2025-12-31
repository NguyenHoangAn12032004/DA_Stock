import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class PlaceOrderUseCase {
  final OrderRepository _repository;

  PlaceOrderUseCase(this._repository);

  Future<Either<Failure, OrderEntity>> call(OrderEntity order) async {
    return await _repository.placeOrder(order);
  }
}

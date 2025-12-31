import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/place_order_usecase.dart';

part 'order_provider.g.dart';

// --- Dependencies ---

@riverpod
OrderRemoteDataSource orderRemoteDataSource(OrderRemoteDataSourceRef ref) {
  return OrderRemoteDataSourceImpl(DioClient.instance);
}

@riverpod
OrderRepository orderRepository(OrderRepositoryRef ref) {
  return OrderRepositoryImpl(ref.watch(orderRemoteDataSourceProvider));
}

@riverpod
PlaceOrderUseCase placeOrderUseCase(PlaceOrderUseCaseRef ref) {
  return PlaceOrderUseCase(ref.watch(orderRepositoryProvider));
}

// --- Controller ---

@riverpod
class OrderController extends _$OrderController {
  @override
  FutureOr<void> build() {
    // Initial state is void (idle)
  }

  Future<void> placeOrder({
    required String userId,
    required String symbol,
    required OrderSide side,
    required int quantity,
    required double price,
    OrderType type = OrderType.limit,
  }) async {
    state = const AsyncLoading();

    final order = OrderEntity(
      userId: userId,
      symbol: symbol,
      side: side,
      quantity: quantity,
      price: price,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final useCase = ref.read(placeOrderUseCaseProvider);
    final result = await useCase(order);

    result.fold(
      (failure) => state = AsyncError(failure.message, StackTrace.current),
      (success) => state = const AsyncData(null),
    );
  }
}

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

final userOrdersProvider = FutureProvider.family<List<OrderEntity>, String>((ref, userId) async {
  final repo = ref.watch(orderRepositoryProvider);
  final result = await repo.getOrders(userId);
  return result.fold((l) => [], (r) => r); 
});


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
      (success) { 
        state = const AsyncData(null);
        ref.invalidate(userOrdersProvider(userId));
      }
    );
  }

  Future<void> cancelOrder(String userId, String orderId) async {
    state = const AsyncLoading();
    // Assuming repo has cancelOrder. If not, will fix in next step.
    final result = await ref.read(orderRepositoryProvider).cancelOrder(userId, orderId);
    
    result.fold(
      (failure) => state = AsyncError(failure.message, StackTrace.current),
      (success) async {
         state = const AsyncData(null);
         // Wait for backend to propagate change (Eventual Consistency)
         await Future.delayed(const Duration(milliseconds: 500));
         ref.invalidate(userOrdersProvider(userId));
      }
    );
  }
}

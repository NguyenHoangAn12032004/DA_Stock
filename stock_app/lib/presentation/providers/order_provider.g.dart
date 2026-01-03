// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$orderRemoteDataSourceHash() =>
    r'b1507d1818102adc4763fd2b6927bf0d03a2e11e';

/// See also [orderRemoteDataSource].
@ProviderFor(orderRemoteDataSource)
final orderRemoteDataSourceProvider =
    AutoDisposeProvider<OrderRemoteDataSource>.internal(
      orderRemoteDataSource,
      name: r'orderRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$orderRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OrderRemoteDataSourceRef =
    AutoDisposeProviderRef<OrderRemoteDataSource>;
String _$orderRepositoryHash() => r'77c8b92481f0b42f91837683ebded09a97aa5bca';

/// See also [orderRepository].
@ProviderFor(orderRepository)
final orderRepositoryProvider = AutoDisposeProvider<OrderRepository>.internal(
  orderRepository,
  name: r'orderRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$orderRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OrderRepositoryRef = AutoDisposeProviderRef<OrderRepository>;
String _$placeOrderUseCaseHash() => r'a4c2800853dd7db9d4d2923e1bc1487fda129253';

/// See also [placeOrderUseCase].
@ProviderFor(placeOrderUseCase)
final placeOrderUseCaseProvider =
    AutoDisposeProvider<PlaceOrderUseCase>.internal(
      placeOrderUseCase,
      name: r'placeOrderUseCaseProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$placeOrderUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlaceOrderUseCaseRef = AutoDisposeProviderRef<PlaceOrderUseCase>;
String _$orderControllerHash() => r'405c27bcc398ad05cdaec5d77e1ca684d25eaa4e';

/// See also [OrderController].
@ProviderFor(OrderController)
final orderControllerProvider =
    AutoDisposeAsyncNotifierProvider<OrderController, void>.internal(
      OrderController.new,
      name: r'orderControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$orderControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OrderController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

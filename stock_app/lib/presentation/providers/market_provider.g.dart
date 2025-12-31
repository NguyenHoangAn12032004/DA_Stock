// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$marketRemoteDataSourceHash() =>
    r'fe2f8075e96e991e39f39dd90f9bc865a07bcfbc';

/// See also [marketRemoteDataSource].
@ProviderFor(marketRemoteDataSource)
final marketRemoteDataSourceProvider =
    AutoDisposeProvider<MarketRemoteDataSource>.internal(
      marketRemoteDataSource,
      name: r'marketRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$marketRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarketRemoteDataSourceRef =
    AutoDisposeProviderRef<MarketRemoteDataSource>;
String _$marketLocalDataSourceHash() =>
    r'1a8136c2daf7db97afb922731bcf05a661d4e876';

/// See also [marketLocalDataSource].
@ProviderFor(marketLocalDataSource)
final marketLocalDataSourceProvider =
    AutoDisposeProvider<MarketLocalDataSource>.internal(
      marketLocalDataSource,
      name: r'marketLocalDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$marketLocalDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarketLocalDataSourceRef =
    AutoDisposeProviderRef<MarketLocalDataSource>;
String _$marketRepositoryHash() => r'496c0f73d6d5a0bbd12f311acfe9001e1108ba6e';

/// See also [marketRepository].
@ProviderFor(marketRepository)
final marketRepositoryProvider = AutoDisposeProvider<MarketRepository>.internal(
  marketRepository,
  name: r'marketRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$marketRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarketRepositoryRef = AutoDisposeProviderRef<MarketRepository>;
String _$getRealtimeQuotesUseCaseHash() =>
    r'83c45ff7eed0e3387095ad76fc715b69717f2892';

/// See also [getRealtimeQuotesUseCase].
@ProviderFor(getRealtimeQuotesUseCase)
final getRealtimeQuotesUseCaseProvider =
    AutoDisposeProvider<GetRealtimeQuotesUseCase>.internal(
      getRealtimeQuotesUseCase,
      name: r'getRealtimeQuotesUseCaseProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$getRealtimeQuotesUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetRealtimeQuotesUseCaseRef =
    AutoDisposeProviderRef<GetRealtimeQuotesUseCase>;
String _$getStockHistoryUseCaseHash() =>
    r'6a6b67af8a2a62b7e82cac5eaf053ecdbe0d0cbc';

/// See also [getStockHistoryUseCase].
@ProviderFor(getStockHistoryUseCase)
final getStockHistoryUseCaseProvider =
    AutoDisposeProvider<GetStockHistoryUseCase>.internal(
      getStockHistoryUseCase,
      name: r'getStockHistoryUseCaseProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$getStockHistoryUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetStockHistoryUseCaseRef =
    AutoDisposeProviderRef<GetStockHistoryUseCase>;
String _$marketDataHash() => r'55591b5ece943ea4330e399f87b49cd70ebc73d3';

/// See also [MarketData].
@ProviderFor(MarketData)
final marketDataProvider =
    AutoDisposeStreamNotifierProvider<MarketData, List<StockEntity>>.internal(
      MarketData.new,
      name: r'marketDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$marketDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MarketData = AutoDisposeStreamNotifier<List<StockEntity>>;
String _$stockListNotifierHash() => r'7facf4c577a1573362e3629f63d8ac7304c9722a';

/// See also [StockListNotifier].
@ProviderFor(StockListNotifier)
final stockListNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      StockListNotifier,
      List<StockEntity>
    >.internal(
      StockListNotifier.new,
      name: r'stockListNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$stockListNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$StockListNotifier = AutoDisposeAsyncNotifier<List<StockEntity>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$portfolioRemoteDataSourceHash() =>
    r'9b3da1c35bb5c4d6ab84925c4ded62b775e91d48';

/// See also [portfolioRemoteDataSource].
@ProviderFor(portfolioRemoteDataSource)
final portfolioRemoteDataSourceProvider =
    AutoDisposeProvider<PortfolioRemoteDataSource>.internal(
      portfolioRemoteDataSource,
      name: r'portfolioRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$portfolioRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PortfolioRemoteDataSourceRef =
    AutoDisposeProviderRef<PortfolioRemoteDataSource>;
String _$portfolioRepositoryHash() =>
    r'c42809eee7abcc7b13dd1ae7e9d19200e01106ad';

/// See also [portfolioRepository].
@ProviderFor(portfolioRepository)
final portfolioRepositoryProvider =
    AutoDisposeProvider<PortfolioRepository>.internal(
      portfolioRepository,
      name: r'portfolioRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$portfolioRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PortfolioRepositoryRef = AutoDisposeProviderRef<PortfolioRepository>;
String _$getPortfolioUseCaseHash() =>
    r'00d9fc5d6d3e576d5fe32c2cc5ac8a7c5f638249';

/// See also [getPortfolioUseCase].
@ProviderFor(getPortfolioUseCase)
final getPortfolioUseCaseProvider =
    AutoDisposeProvider<GetPortfolioUseCase>.internal(
      getPortfolioUseCase,
      name: r'getPortfolioUseCaseProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$getPortfolioUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetPortfolioUseCaseRef = AutoDisposeProviderRef<GetPortfolioUseCase>;
String _$portfolioStreamHash() => r'89689868bd28d54200f864e72d2e0b94fad18762';

/// See also [portfolioStream].
@ProviderFor(portfolioStream)
final portfolioStreamProvider =
    AutoDisposeStreamProvider<PortfolioEntity>.internal(
      portfolioStream,
      name: r'portfolioStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$portfolioStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PortfolioStreamRef = AutoDisposeStreamProviderRef<PortfolioEntity>;
String _$portfolioControllerHash() =>
    r'7033ef78f879a1dc6db16725c8daa41049d0b3e5';

/// See also [PortfolioController].
@ProviderFor(PortfolioController)
final portfolioControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      PortfolioController,
      PortfolioState
    >.internal(
      PortfolioController.new,
      name: r'portfolioControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$portfolioControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PortfolioController = AutoDisposeAsyncNotifier<PortfolioState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

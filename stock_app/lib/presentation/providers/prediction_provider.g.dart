// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prediction_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$predictionRemoteDataSourceHash() =>
    r'8adea211e28a60fc55b37372e67fa25260e79619';

/// See also [predictionRemoteDataSource].
@ProviderFor(predictionRemoteDataSource)
final predictionRemoteDataSourceProvider =
    AutoDisposeProvider<PredictionRemoteDataSource>.internal(
      predictionRemoteDataSource,
      name: r'predictionRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$predictionRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PredictionRemoteDataSourceRef =
    AutoDisposeProviderRef<PredictionRemoteDataSource>;
String _$predictionRepositoryHash() =>
    r'dd5d3512580431bd3c5c288def32019d801bbc26';

/// See also [predictionRepository].
@ProviderFor(predictionRepository)
final predictionRepositoryProvider =
    AutoDisposeProvider<PredictionRepository>.internal(
      predictionRepository,
      name: r'predictionRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$predictionRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PredictionRepositoryRef = AutoDisposeProviderRef<PredictionRepository>;
String _$getPredictionUseCaseHash() =>
    r'ceb87ef6e7757d78695aa2e2300ce113f6ad0466';

/// See also [getPredictionUseCase].
@ProviderFor(getPredictionUseCase)
final getPredictionUseCaseProvider =
    AutoDisposeProvider<GetPredictionUseCase>.internal(
      getPredictionUseCase,
      name: r'getPredictionUseCaseProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$getPredictionUseCaseHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetPredictionUseCaseRef = AutoDisposeProviderRef<GetPredictionUseCase>;
String _$predictionControllerHash() =>
    r'604324d99f76013deb4bd24a67200ac12ccdca7b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$PredictionController
    extends BuildlessAutoDisposeAsyncNotifier<PredictionEntity?> {
  late final String symbol;

  FutureOr<PredictionEntity?> build(String symbol);
}

/// See also [PredictionController].
@ProviderFor(PredictionController)
const predictionControllerProvider = PredictionControllerFamily();

/// See also [PredictionController].
class PredictionControllerFamily extends Family<AsyncValue<PredictionEntity?>> {
  /// See also [PredictionController].
  const PredictionControllerFamily();

  /// See also [PredictionController].
  PredictionControllerProvider call(String symbol) {
    return PredictionControllerProvider(symbol);
  }

  @override
  PredictionControllerProvider getProviderOverride(
    covariant PredictionControllerProvider provider,
  ) {
    return call(provider.symbol);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'predictionControllerProvider';
}

/// See also [PredictionController].
class PredictionControllerProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          PredictionController,
          PredictionEntity?
        > {
  /// See also [PredictionController].
  PredictionControllerProvider(String symbol)
    : this._internal(
        () => PredictionController()..symbol = symbol,
        from: predictionControllerProvider,
        name: r'predictionControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$predictionControllerHash,
        dependencies: PredictionControllerFamily._dependencies,
        allTransitiveDependencies:
            PredictionControllerFamily._allTransitiveDependencies,
        symbol: symbol,
      );

  PredictionControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.symbol,
  }) : super.internal();

  final String symbol;

  @override
  FutureOr<PredictionEntity?> runNotifierBuild(
    covariant PredictionController notifier,
  ) {
    return notifier.build(symbol);
  }

  @override
  Override overrideWith(PredictionController Function() create) {
    return ProviderOverride(
      origin: this,
      override: PredictionControllerProvider._internal(
        () => create()..symbol = symbol,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        symbol: symbol,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    PredictionController,
    PredictionEntity?
  >
  createElement() {
    return _PredictionControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PredictionControllerProvider && other.symbol == symbol;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, symbol.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PredictionControllerRef
    on AutoDisposeAsyncNotifierProviderRef<PredictionEntity?> {
  /// The parameter `symbol` of this provider.
  String get symbol;
}

class _PredictionControllerProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          PredictionController,
          PredictionEntity?
        >
    with PredictionControllerRef {
  _PredictionControllerProviderElement(super.provider);

  @override
  String get symbol => (origin as PredictionControllerProvider).symbol;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

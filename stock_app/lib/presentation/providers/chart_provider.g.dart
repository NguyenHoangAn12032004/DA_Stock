// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chartStateHash() => r'cf642aab7eff1c285ae3b9d5c7842aa1831ec955';

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

abstract class _$ChartState
    extends BuildlessAutoDisposeAsyncNotifier<List<ChartDataEntity>> {
  late final String symbol;
  late final String timeframe;

  FutureOr<List<ChartDataEntity>> build(String symbol, String timeframe);
}

/// See also [ChartState].
@ProviderFor(ChartState)
const chartStateProvider = ChartStateFamily();

/// See also [ChartState].
class ChartStateFamily extends Family<AsyncValue<List<ChartDataEntity>>> {
  /// See also [ChartState].
  const ChartStateFamily();

  /// See also [ChartState].
  ChartStateProvider call(String symbol, String timeframe) {
    return ChartStateProvider(symbol, timeframe);
  }

  @override
  ChartStateProvider getProviderOverride(
    covariant ChartStateProvider provider,
  ) {
    return call(provider.symbol, provider.timeframe);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chartStateProvider';
}

/// See also [ChartState].
class ChartStateProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ChartState,
          List<ChartDataEntity>
        > {
  /// See also [ChartState].
  ChartStateProvider(String symbol, String timeframe)
    : this._internal(
        () => ChartState()
          ..symbol = symbol
          ..timeframe = timeframe,
        from: chartStateProvider,
        name: r'chartStateProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$chartStateHash,
        dependencies: ChartStateFamily._dependencies,
        allTransitiveDependencies: ChartStateFamily._allTransitiveDependencies,
        symbol: symbol,
        timeframe: timeframe,
      );

  ChartStateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.symbol,
    required this.timeframe,
  }) : super.internal();

  final String symbol;
  final String timeframe;

  @override
  FutureOr<List<ChartDataEntity>> runNotifierBuild(
    covariant ChartState notifier,
  ) {
    return notifier.build(symbol, timeframe);
  }

  @override
  Override overrideWith(ChartState Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChartStateProvider._internal(
        () => create()
          ..symbol = symbol
          ..timeframe = timeframe,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        symbol: symbol,
        timeframe: timeframe,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ChartState, List<ChartDataEntity>>
  createElement() {
    return _ChartStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChartStateProvider &&
        other.symbol == symbol &&
        other.timeframe == timeframe;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, symbol.hashCode);
    hash = _SystemHash.combine(hash, timeframe.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ChartStateRef
    on AutoDisposeAsyncNotifierProviderRef<List<ChartDataEntity>> {
  /// The parameter `symbol` of this provider.
  String get symbol;

  /// The parameter `timeframe` of this provider.
  String get timeframe;
}

class _ChartStateProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ChartState,
          List<ChartDataEntity>
        >
    with ChartStateRef {
  _ChartStateProviderElement(super.provider);

  @override
  String get symbol => (origin as ChartStateProvider).symbol;
  @override
  String get timeframe => (origin as ChartStateProvider).timeframe;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

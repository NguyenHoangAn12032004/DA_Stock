// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$aiRemoteDataSourceHash() =>
    r'2fe322d8ce2b6b7fb0b6a4dd1fcca33b6e5a403f';

/// See also [aiRemoteDataSource].
@ProviderFor(aiRemoteDataSource)
final aiRemoteDataSourceProvider =
    AutoDisposeProvider<AiRemoteDataSource>.internal(
      aiRemoteDataSource,
      name: r'aiRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$aiRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AiRemoteDataSourceRef = AutoDisposeProviderRef<AiRemoteDataSource>;
String _$aiRepositoryHash() => r'3938831b1af46a8c9675c608e4c6a26b8c9423eb';

/// See also [aiRepository].
@ProviderFor(aiRepository)
final aiRepositoryProvider = AutoDisposeProvider<AiRepository>.internal(
  aiRepository,
  name: r'aiRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$aiRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AiRepositoryRef = AutoDisposeProviderRef<AiRepository>;
String _$chatControllerHash() => r'a4889c83fb695e47efaa254b73649ab66ba1ca03';

/// See also [ChatController].
@ProviderFor(ChatController)
final chatControllerProvider =
    AutoDisposeNotifierProvider<ChatController, List<ChatMessage>>.internal(
      ChatController.new,
      name: r'chatControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$chatControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ChatController = AutoDisposeNotifier<List<ChatMessage>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

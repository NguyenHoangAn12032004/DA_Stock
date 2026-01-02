import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/social_remote_datasource.dart';
import '../../data/repositories/social_repository_impl.dart';
import '../../domain/repositories/social_repository.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/leaderboard_entity.dart';

// Repository Provider
final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  final dioClient = DioClient.instance;
  final dataSource = SocialRemoteDataSource(dioClient);
  return SocialRepositoryImpl(dataSource);
});

// Leaderboard FutureProvider
final leaderboardProvider = FutureProvider<List<LeaderboardEntity>>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getLeaderboard();
});

final feedProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  return repo.getFeed();
});

// Follow Action Provider
final socialControllerProvider = StateNotifierProvider<SocialController, AsyncValue<void>>((ref) {
  final repo = ref.watch(socialRepositoryProvider);
  return SocialController(repo);
});

class SocialController extends StateNotifier<AsyncValue<void>> {
  final SocialRepository _repo;

  SocialController(this._repo) : super(const AsyncValue.data(null));

  Future<void> followUser(String targetUserId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.followUser(targetUserId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

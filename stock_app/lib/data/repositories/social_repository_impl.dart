import '../../domain/entities/leaderboard_entity.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/social_remote_datasource.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialRepositoryImpl implements SocialRepository {
  final SocialRemoteDataSource _remoteDataSource;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SocialRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<LeaderboardEntity>> getLeaderboard() async {
    final rawList = await _remoteDataSource.getLeaderboard();
    return rawList.map((json) {
      return LeaderboardEntity(
        userId: json['user_id'] ?? '',
        name: json['name'] ?? 'Unknown',
        equity: (json['equity'] as num?)?.toDouble() ?? 0.0,
        roi: (json['roi'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  @override
  Future<void> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not logged in");
    await _remoteDataSource.followUser(currentUser.uid, targetUserId);
  }

  @override
  Future<Map<String, dynamic>> getTraderProfile(String targetUserId) async {
    return await _remoteDataSource.getTraderProfile(targetUserId);
  }

  @override
  Future<List<Map<String, dynamic>>> getFeed() async {
    final rawList = await _remoteDataSource.getFeed();
    return rawList.cast<Map<String, dynamic>>();
  }
}

import '../entities/leaderboard_entity.dart';

abstract class SocialRepository {
  Future<List<LeaderboardEntity>> getLeaderboard();
  Future<void> followUser(String targetUserId);
  Future<Map<String, dynamic>> getTraderProfile(String targetUserId);
  Future<List<Map<String, dynamic>>> getFeed(); // New
}

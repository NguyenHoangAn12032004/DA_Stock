import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';

class SocialRemoteDataSource {
  final DioClient _dioClient;

  SocialRemoteDataSource(this._dioClient);

  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await _dioClient.dio.get('/api/social/leaderboard');
      // Backend returns { "data": [ ... ] }
      return response.data['data'];
    } catch (e) {
      throw Exception('Failed to fetch leaderboard: $e');
    }
  }

  Future<void> followUser(String followerId, String leaderId) async {
    try {
      await _dioClient.dio.post('/api/social/follow', queryParameters: {
        'follower_id': followerId,
        'leader_id': leaderId,
      });
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  Future<Map<String, dynamic>> getTraderProfile(String targetId) async {
    try {
      final response = await _dioClient.dio.get('/api/social/profile/$targetId');
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  Future<List<dynamic>> getFeed() async {
    try {
      print('🔍 FRONTEND: Fetching social feed...');
      final response = await _dioClient.dio.get('/api/social/feed');
      print('✅ FRONTEND: Feed Status ${response.statusCode}, Data: ${response.data}');
      return response.data['data'];
    } catch (e) {
      print('❌ FRONTEND: Feed Error: $e');
      throw Exception('Failed to fetch feed: $e');
    }
  }
}

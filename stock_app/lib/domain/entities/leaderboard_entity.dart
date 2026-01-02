class LeaderboardEntity {
  final String userId;
  final String name;
  final double equity;
  final double roi;
  final bool isFollowing; // For UI state

  LeaderboardEntity({
    required this.userId,
    required this.name,
    required this.equity,
    required this.roi,
    this.isFollowing = false,
  });
}

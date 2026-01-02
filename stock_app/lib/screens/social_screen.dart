import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/social_provider.dart';
import '../theme/app_colors.dart';
import '../models/stock_data.dart'; // Just for consistency if needed, maybe not
import '../core/utils/currency_helper.dart'; // Actually needed for formatting equity
import 'package:intl/intl.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng đồng Đầu tư', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Xếp hạng'),
            Tab(text: 'Bảng tin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(isDark),
          _buildFeedTab(isDark),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(bool isDark) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(leaderboardProvider.future),
      child: leaderboardAsync.when(
        data: (users) {
          if (users.isEmpty) {
             return const Center(child: Text("Chưa có dữ liệu xếp hạng"));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildLeaderboardItem(user, index + 1, isDark);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildLeaderboardItem(user, int rank, bool isDark) {
    // Handling colors for Top 3
    final Color? rankColor = rank == 1 ? const Color(0xFFFFD700) : 
                             rank == 2 ? const Color(0xFFC0C0C0) : 
                             rank == 3 ? const Color(0xFFCD7F32) : null;
    
    final isPositive = user.roi >= 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
           if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 30,
            alignment: Alignment.center,
            child: rank <= 3 
              ? Icon(Icons.emoji_events, color: rankColor, size: 28)
              : Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(user.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Vốn: ${NumberFormat.compact().format(user.equity)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? "+" : ""}${user.roi.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPositive ? AppColors.success : AppColors.danger,
                  fontSize: 16
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _handleFollow(user.userId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Theo dõi", 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  void _handleFollow(String userId) async {
    await ref.read(socialControllerProvider.notifier).followUser(userId);
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã theo dõi thành công!')));
    }
  }

  Widget _buildFeedTab(bool isDark) {
    final feedAsync = ref.watch(feedProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(feedProvider.future),
      child: feedAsync.when(
        data: (trades) {
          if (trades.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.feed_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                   const SizedBox(height: 16),
                   const Text("Chưa có hoạt động giao dịch nào", style: TextStyle(color: Colors.grey)),
                 ],
               )
             );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: trades.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trade = trades[index];
              // Format Time
              final timestamp = trade['timestamp'] as int? ?? 0;
              final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
              final timeFormatted = DateFormat("HH:mm").format(dt);
              
              final quantity = trade['quantity'] ?? 0;
              final price = trade['price'] ?? 0;
              final actionText = "${trade['action'] == 'mua' ? 'đã mua' : 'đã bán'} ${NumberFormat.decimalPattern().format(quantity)} CP giá ${NumberFormat.decimalPattern().format(price)}";

              return _buildFeedItem(
                trade['user_name'] ?? 'Trader', 
                trade['symbol'] ?? '', 
                actionText, 
                timeFormatted, 
                isDark,
                isBuy: trade['action'] == 'mua'
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildFeedItem(String user, String symbol, String action, String time, bool isDark, {bool isBuy = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: isBuy ? AppColors.success : AppColors.danger, width: 4))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           CircleAvatar(
             radius: 18,
             backgroundColor: isBuy ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
             child: Text(user.isNotEmpty ? user[0].toUpperCase() : '?', 
                style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontSize: 14, fontWeight: FontWeight.bold)
             ),
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(user, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                       Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                      children: [
                        const TextSpan(text: "Vừa "),
                        TextSpan(text: symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const TextSpan(text: ": "),
                        TextSpan(text: action),
                      ]
                    ),
                  )
                ],
             ),
           )
        ],
      ),
    );
  }
}

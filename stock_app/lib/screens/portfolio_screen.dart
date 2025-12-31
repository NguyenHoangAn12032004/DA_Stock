import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/entities/order_entity.dart';
import '../domain/entities/portfolio_entity.dart';
import '../domain/entities/holding_entity.dart';
import '../presentation/providers/portfolio_provider.dart';
import '../presentation/providers/order_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/settings_provider.dart';
import '../theme/app_colors.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> with SingleTickerProviderStateMixin {
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
    final bgColor = isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Portfolio'),
        backgroundColor: isDark ? const Color(0xFF111418) : Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.grey : Colors.black54,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Assets'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(portfolioControllerProvider.notifier).refresh();
        },
        child: TabBarView(
          controller: _tabController,
          children: [
             _buildAssetsTab(isDark),
             _buildHistoryTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsTab(bool isDark) {
    final portfolioState = ref.watch(portfolioControllerProvider);

    return portfolioState.when(
      data: (state) {
        final portfolio = state.portfolio;
        if (portfolio == null) {
           return const Center(child: Text("Please login to view portfolio"));
        }
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
             _buildBalanceCard(state, isDark),
             const SizedBox(height: 16),
             const Text("Holdings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             if (portfolio.holdings.isEmpty)
               const Center(child: Padding(
                 padding: EdgeInsets.all(32.0),
                 child: Text("No assets held"),
               ))
             else
               ...portfolio.holdings.map((holding) => _buildHoldingItem(holding, state.currentPrices, isDark)).toList(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildBalanceCard(PortfolioState state, bool isDark) {
    // 1. Get Language from Provider
    final language = ref.watch(languageControllerProvider).valueOrNull ?? 'English';
    final isVietnamese = language == 'Vietnamese'; // Normalized check
    final locale = isVietnamese ? 'vi_VN' : 'en_US';
    final symbol = isVietnamese ? '₫' : '\$';
    
    // 2. Localization Map (Simple inline for MVP)
    final labels = isVietnamese ? {
      'Total Equity': 'Tổng Tài Sản',
      'Cash Balance': 'Tiền Mặt',
      'Invested': 'Đã Đầu Tư',
    } : {
      'Total Equity': 'Total Equity',
      'Cash Balance': 'Cash Balance',
      'Invested': 'Invested',
    };

    final totalValue = state.totalEquity;
    final cashBalance = state.cashBalance;
    final invested = state.invested;
    final pnl = state.totalPnL;
    final pnlPercent = state.totalPnLPercent;
    
    final isProfit = pnl >= 0;
    final pnlColor = isProfit ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2630) : AppColors.primary, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(labels['Total Equity']!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(locale: locale, symbol: symbol).format(totalValue),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          // PnL Row
          Row(
            children: [
               Icon(
                 isProfit ? Icons.trending_up : Icons.trending_down,
                 color: pnlColor,
                 size: 20,
               ),
               const SizedBox(width: 4),
               Text(
                 "${isProfit ? '+' : ''}${NumberFormat.currency(locale: locale, symbol: symbol).format(pnl)} (${pnlPercent.toStringAsFixed(2)}%)",
                 style: TextStyle(color: pnlColor, fontSize: 16, fontWeight: FontWeight.bold),
               ),
            ],
          ),
          
          const Divider(color: Colors.white24, height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(labels['Cash Balance']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                   Text(
                    NumberFormat.currency(locale: locale, symbol: symbol).format(cashBalance),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(labels['Invested']!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                   Text(
                    NumberFormat.currency(locale: locale, symbol: symbol).format(invested),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHoldingItem(HoldingEntity holding, Map<String, double> currentPrices, bool isDark) {
    // 1. Localization
    final language = ref.watch(languageControllerProvider).valueOrNull ?? 'English';
    final isVietnamese = language == 'Vietnamese';
    final locale = isVietnamese ? 'vi_VN' : 'en_US';
    final symbol = isVietnamese ? '₫' : '\$';

    // Determine real-time value
    final currentPrice = currentPrices[holding.symbol] ?? holding.averagePrice;
    final totalValue = holding.quantity * currentPrice;
    final investedValue = holding.quantity * holding.averagePrice;
    final pnl = totalValue - investedValue;
    final pnlPercent = investedValue > 0 ? (pnl / investedValue) * 100 : 0.0;
    
    final isProfit = pnl >= 0;
    final pnlColor = isProfit ? AppColors.success : AppColors.danger;

    return Card(
      elevation: 0,
       color: isDark ? const Color(0xFF1A2028) : Colors.white,
       margin: const EdgeInsets.only(bottom: 8),
       child: InkWell( // Make tappable
         onTap: () {
           context.push('/stock/${holding.symbol}');
         },
         child: Padding(
           padding: const EdgeInsets.all(12.0),
           child: Row(
             children: [
               CircleAvatar(
                 backgroundColor: AppColors.primary.withOpacity(0.1),
                 child: Text(holding.symbol[0], style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(holding.symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     Text("${holding.quantity} Share${holding.quantity > 1 ? 's' : ''}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey[700])),
                   ],
                 ),
               ),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   Text(
                     NumberFormat.currency(locale: locale, symbol: symbol).format(totalValue),
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                   ),
                   Row(
                     children: [
                       Text(
                         "${isProfit ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%",
                         style: TextStyle(fontSize: 12, color: pnlColor, fontWeight: FontWeight.bold),
                       ),
                       Text(
                         " | ${NumberFormat.currency(locale: locale, symbol: symbol).format(currentPrice)}",
                         style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey[600]),
                       ),
                     ],
                   ),
                 ],
               ),
             ],
           ),
         ),
       ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    final portfolioState = ref.watch(portfolioControllerProvider);

    return portfolioState.when(
      data: (state) {
        final orders = state.orders;
        if (orders.isEmpty) {
           return const Center(child: Text("No order history"));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
             final order = orders[index];
             return _buildOrderItem(order, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error loading history: $e")),
    );
  }

  Widget _buildOrderItem(OrderEntity order, bool isDark) {
     // 1. Localization
     final language = ref.watch(languageControllerProvider).valueOrNull ?? 'English';
     final isVietnamese = language == 'Vietnamese';
     final locale = isVietnamese ? 'vi_VN' : 'en_US';
     final symbol = isVietnamese ? '₫' : '\$';
     
     final isBuy = order.side == OrderSide.buy;
     final statusColor = _getStatusColor(order.status);

     return Card(
        elevation: 0,
        color: isDark ? const Color(0xFF1A2028) : Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            isBuy ? Icons.download : Icons.upload,
            color: isBuy ? AppColors.success : AppColors.danger,
          ),
          title: Text("${isBuy ? 'BUY' : 'SELL'} ${order.symbol}"),
          subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(order.timestamp * 1000))),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${order.quantity} @ ${NumberFormat.currency(locale: locale, symbol: symbol).format(order.price)}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormat.currency(locale: locale, symbol: symbol).format(order.price * order.quantity),
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isBuy ? AppColors.danger : AppColors.success), 
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4)
                ),
                child: Text(
                  order.status.name.toUpperCase(),
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
     );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.matched: return AppColors.success;
      case OrderStatus.pending: return Colors.orange;
      case OrderStatus.canceled: return Colors.grey;
    }
  }
}

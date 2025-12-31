import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/entities/order_entity.dart';
import '../domain/entities/portfolio_entity.dart';
import '../presentation/providers/portfolio_provider.dart';
import '../presentation/providers/order_provider.dart';
import '../presentation/providers/auth_provider.dart';
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
               ...portfolio.holdings.map((holding) => _buildHoldingItem(holding, isDark)).toList(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Error: $e")),
    );
  }

  Widget _buildBalanceCard(dynamic state, bool isDark) { // Using dynamic or PortfolioState type if imported
    // Values are pre-calculated in Provider
    final totalValue = state.totalEquity;
    final cashBalance = state.cashBalance;
    final invested = state.invested;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Total Equity", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(locale: 'en_US', symbol: '\$').format(totalValue),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Cash Balance", style: TextStyle(color: Colors.white70, fontSize: 12)),
                   Text(
                    NumberFormat.currency(locale: 'en_US', symbol: '\$').format(cashBalance),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   const Text("Invested", style: TextStyle(color: Colors.white70, fontSize: 12)),
                   Text(
                    NumberFormat.currency(locale: 'en_US', symbol: '\$').format(invested),
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

  Widget _buildHoldingItem(holding, bool isDark) {
    return Card(
      elevation: 0,
       color: isDark ? const Color(0xFF1A2028) : Colors.white,
       margin: const EdgeInsets.only(bottom: 8),
       child: ListTile(
         onTap: () {
           context.push('/stock/${holding.symbol}');
         },
         leading: CircleAvatar(
           backgroundColor: AppColors.primary.withOpacity(0.1),
           child: Text(holding.symbol[0], style: TextStyle(color: AppColors.primary)),
         ),
         title: Text(holding.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
         subtitle: Text("${holding.quantity} Shares"),
         trailing: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           crossAxisAlignment: CrossAxisAlignment.end,
           children: [
             Text(
               NumberFormat.currency(locale: 'en_US', symbol: '\$').format(holding.totalValue),
               style: const TextStyle(fontWeight: FontWeight.bold),
             ),
             Text(
               "Avg: \$${holding.averagePrice.toStringAsFixed(2)}",
               style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.black54),
             ),
           ],
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
                "${order.quantity} @ ${order.price}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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

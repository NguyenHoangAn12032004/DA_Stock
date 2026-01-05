import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import 'stock_detail_screen.dart';
import '../core/utils/currency_helper.dart';
import '../presentation/providers/settings_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _allStocks = [
    // VN Stocks
    {'symbol': 'HPG', 'name': 'Hoa Phat Group', 'type': 'VN', 'price': 27400, 'change': 2.5},
    {'symbol': 'VCB', 'name': 'Vietcombank', 'type': 'VN', 'price': 88200, 'change': -1.2},
    {'symbol': 'FPT', 'name': 'FPT Corp', 'type': 'VN', 'price': 96500, 'change': 1.8},
    {'symbol': 'VNM', 'name': 'Vinamilk', 'type': 'VN', 'price': 67800, 'change': -0.5},
    {'symbol': 'TCB', 'name': 'Techcombank', 'type': 'VN', 'price': 34500, 'change': 3.1},
    {'symbol': 'MSN', 'name': 'Masan Group', 'type': 'VN', 'price': 64200, 'change': -2.1},
    {'symbol': 'SSI', 'name': 'SSI Securities', 'type': 'VN', 'price': 32100, 'change': 4.2},
    {'symbol': 'VIC', 'name': 'Vingroup', 'type': 'VN', 'price': 45600, 'change': -0.8},
    {'symbol': 'VHM', 'name': 'Vinhomes', 'type': 'VN', 'price': 41200, 'change': 0.5},
    {'symbol': 'MWG', 'name': 'Mobile World', 'type': 'VN', 'price': 48900, 'change': 1.2},
    
    // US Stocks
    {'symbol': 'AAPL', 'name': 'Apple Inc.', 'type': 'US', 'price': 185.64, 'change': 1.5},
    {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'type': 'US', 'price': 234.56, 'change': -3.2},
    {'symbol': 'NVDA', 'name': 'NVIDIA Corp', 'type': 'US', 'price': 487.23, 'change': 5.4},
    {'symbol': 'MSFT', 'name': 'Microsoft', 'type': 'US', 'price': 378.90, 'change': 0.8},
    {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'type': 'US', 'price': 142.34, 'change': -0.5},
    {'symbol': 'AMZN', 'name': 'Amazon.com', 'type': 'US', 'price': 154.67, 'change': 1.1},
    {'symbol': 'META', 'name': 'Meta Platforms', 'type': 'US', 'price': 356.78, 'change': 2.3},
    
    // Crypto
    {'symbol': 'BTC-USD', 'name': 'Bitcoin', 'type': 'Crypto', 'price': 43567.89, 'change': 2.1},
    {'symbol': 'ETH-USD', 'name': 'Ethereum', 'type': 'Crypto', 'price': 2345.67, 'change': -1.1},
    {'symbol': 'BNB-USD', 'name': 'Binance Coin', 'type': 'Crypto', 'price': 312.45, 'change': 0.5},
    {'symbol': 'SOL-USD', 'name': 'Solana', 'type': 'Crypto', 'price': 98.76, 'change': 4.5},
    {'symbol': 'XRP-USD', 'name': 'XRP', 'type': 'Crypto', 'price': 0.62, 'change': -0.2},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Trigger Forex fetch if not already done.
    // Provider auto-fetches when watched. We'll watch in build.
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredStocks(String type) {
    return _allStocks.where((stock) {
      final matchesType = type == 'All' || stock['type'] == type;
      final matchesSearch = stock['symbol'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            stock['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2633) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi') 
                  ? 'Tìm kiếm mã cổ phiếu...' 
                  : 'Search stock symbol...',
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
          indicatorColor: AppColors.primary,
          tabs: (ref.watch(languageControllerProvider).valueOrNull?.languageCode == 'vi')
             ? const [
                Tab(text: 'Tất cả'),
                Tab(text: 'Việt Nam'),
                Tab(text: 'Quốc tế'),
                Tab(text: 'Crypto'),
               ]
             : const [
                Tab(text: 'All'),
                Tab(text: 'Vietnam'),
                Tab(text: 'Global'),
                Tab(text: 'Crypto'),
               ],
          ),
        ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockList(isDark, 'All'),
          _buildStockList(isDark, 'VN'),
          _buildStockList(isDark, 'US'),
          _buildStockList(isDark, 'Crypto'),
        ],
      ),
    );
  }

  Widget _buildStockList(bool isDark, String type) {
    // Watch language
    final Locale locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
    // Watch Forex to trigger update
    ref.watch(forexRateProvider); // Fire and forget (it updates Helper static)

    final stocks = _getFilteredStocks(type);

    if (stocks.isEmpty) {
      return Center(
        child: Text(
          (locale.languageCode == 'vi') ? 'Không tìm thấy kết quả' : 'No results found',
          style: TextStyle(
            color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
         // Refresh Forex rates as a proxy for "refreshing data"
         ref.invalidate(forexRateProvider);
         // Simulate a small delay for feeling
         await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: stocks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final stock = stocks[index];
          final isUp = stock['change'] >= 0;
          final color = isUp ? AppColors.success : AppColors.danger;
          final price = (stock['price'] as num).toDouble();

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockDetailScreen(symbol: stock['symbol']),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2633) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        stock['symbol'][0],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock['symbol'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF111418),
                          ),
                        ),
                        Text(
                          stock['name'],
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyHelper.format(price, symbol: stock['symbol'], locale: locale),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF111418),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                            color: color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stock['change']}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

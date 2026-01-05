import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../theme/app_colors.dart';
import 'stock_detail_screen.dart';
import '../core/utils/currency_helper.dart';
import '../presentation/providers/settings_provider.dart';
import '../core/network/dio_client.dart';

// --- Provider to Fetch Batch Quotes ---
final discoverStocksProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, symbolsStr) async {
  final dio = DioClient.instance.dio;
  try {
    // API expects: /api/stock/batch_quotes?symbols=HPG,VCB,AAPL
    final response = await dio.get(
      '/api/stock/batch_quotes',
      queryParameters: {'symbols': symbolsStr},
    );
    
    // Map response "data": { "HPG": {...}, "VCB": {...} } to List
    final dataMap = response.data['data'] as Map<String, dynamic>;
    final List<Map<String, dynamic>> results = [];
    
    final symbols = symbolsStr.split(',');
    for (var sym in symbols) {
      if (dataMap.containsKey(sym)) {
        results.add(dataMap[sym]);
      } else {
        // Fallback for missing data
        results.add({
          'symbol': sym,
          'price': 0.0,
          'change_percent': 0.0,
          'name': sym // Placeholder
        });
      }
    }
    return results;
  } catch (e) {
    print("Batch Quote Error: $e");
    return [];
  }
});

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Static Definition of Symbols (Directory)
  final Map<String, List<Map<String, String>>> _stockDirectory = {
    'VN': [
      {'symbol': 'HPG', 'name': 'Hoa Phat Group'},
      {'symbol': 'VCB', 'name': 'Vietcombank'},
      {'symbol': 'FPT', 'name': 'FPT Corp'},
      {'symbol': 'VNM', 'name': 'Vinamilk'},
      {'symbol': 'TCB', 'name': 'Techcombank'},
      {'symbol': 'MSN', 'name': 'Masan Group'},
      {'symbol': 'SSI', 'name': 'SSI Securities'},
      {'symbol': 'VIC', 'name': 'Vingroup'},
      {'symbol': 'VHM', 'name': 'Vinhomes'},
      {'symbol': 'MWG', 'name': 'Mobile World'},
    ],
    'US': [
      {'symbol': 'AAPL', 'name': 'Apple Inc.'},
      {'symbol': 'TSLA', 'name': 'Tesla Inc.'},
      {'symbol': 'NVDA', 'name': 'NVIDIA Corp'},
      {'symbol': 'MSFT', 'name': 'Microsoft'},
      {'symbol': 'GOOGL', 'name': 'Alphabet Inc.'},
      {'symbol': 'AMZN', 'name': 'Amazon.com'},
      {'symbol': 'META', 'name': 'Meta Platforms'},
    ],
    'Crypto': [
      {'symbol': 'BTC-USD', 'name': 'Bitcoin'},
      {'symbol': 'ETH-USD', 'name': 'Ethereum'},
      {'symbol': 'BNB-USD', 'name': 'Binance Coin'},
      {'symbol': 'SOL-USD', 'name': 'Solana'},
      {'symbol': 'XRP-USD', 'name': 'XRP'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getFilteredSymbols(String type) {
    List<Map<String, String>> all = [];
    if (type == 'All') {
      all = [
        ..._stockDirectory['VN']!,
        ..._stockDirectory['US']!,
        ..._stockDirectory['Crypto']!
      ];
    } else {
      all = _stockDirectory[type] ?? [];
    }

    if (_searchQuery.isEmpty) return all;

    return all.where((s) =>
      s['symbol']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      s['name']!.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
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
        title: _buildSearchBar(isDark),
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

  Widget _buildSearchBar(bool isDark) {
    return Container(
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
        onChanged: (value) => setState(() => _searchQuery = value),
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
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _buildStockList(bool isDark, String type) {
    final Locale locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
    
    // 1. Get List of Symbols to Show
    final stockItems = _getFilteredSymbols(type);
    final symbols = stockItems.map((e) => e['symbol']!).toList();

    if (stockItems.isEmpty) {
      return Center(
        child: Text(
          (locale.languageCode == 'vi') ? 'Không tìm thấy kết quả' : 'No results found',
          style: TextStyle(color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588)),
        ),
      );
    }

    // 2. Fetch Real Data for these symbols
    final asyncData = ref.watch(discoverStocksProvider(symbols.join(',')));

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading data')),
      data: (realDataList) {
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(discoverStocksProvider(symbols.join(','))),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: stockItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // Merge Directory Info with Real Data
              final info = stockItems[index];
              final symbol = info['symbol']!;
              
              // Find matching real data
              final data = realDataList.firstWhere(
                (element) => element['symbol'] == symbol,
                orElse: () => {'price': 0.0, 'change_percent': 0.0},
              );

              final price = (data['price'] as num).toDouble();
              final change = (data['change_percent'] as num).toDouble();
              final isUp = change >= 0;
              final color = isUp ? AppColors.success : AppColors.danger;

              // Force VND for VN stocks (Simple heuristic: 3 chars + No numbers)
              // Or check if it's in the VN list
              final isVN = _stockDirectory['VN']!.any((e) => e['symbol'] == symbol);
              
              // Formatting
              String priceStr = CurrencyHelper.format(price, symbol: symbol, locale: locale);

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StockDetailScreen(symbol: symbol),
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
                            symbol[0],
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
                              symbol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : const Color(0xFF111418),
                              ),
                            ),
                            Text(
                              info['name']!,
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
                            priceStr,
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
                                '${change.toStringAsFixed(2)}%',
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
      },
    );
  }
}

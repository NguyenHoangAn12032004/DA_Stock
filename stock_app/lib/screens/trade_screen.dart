import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Already added in the chunk above, but ensuring consistency if needed.
// Wait, I put it in the chunk above. But I need to remove it from here if I added it above? 
// No, the chunk above replaces lines 14-23. The top file content (lines 1-13) is separate.
// I should check if I need to add import at top if I haven't.
// The previous tool call output shows imports:
// 1: import 'package:flutter/material.dart';
// 2: import 'package:intl/intl.dart';
// ...
// So I need to add flutter_riverpod import at the top too?
// Actually, the previous chunk added it in the ReplacementContent? 
// "import 'package:flutter_riverpod/flutter_riverpod.dart';" was in the ReplacementContent above.
// But that chunk replaced the Class definition. It put imports right before the class? 
// That's valid Dart but might look messy if duplicates exist at top.
// Let's just add it cleanly at the top and remove it from the class chunk if possible, OR just proceed. 
// The provided chunk puts imports *before* the class. Code is:
// imports...
// class TradeScreen...
// So inserting imports before class TradeScreen is fine.
// BUT, I should check existing imports.
// Lines 1-12 are imports.
// Line 14 is class TradeScreen.
// So inserting imports at line 14 works.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock_data.dart';
import '../models/company_overview.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/stock_chart.dart';
import 'order_history_screen.dart';
import '../core/utils/stock_utils.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/settings_provider.dart';
import '../presentation/providers/portfolio_provider.dart'; 
import '../presentation/providers/order_provider.dart';   
import '../core/utils/currency_helper.dart';
import '../domain/entities/holding_entity.dart';
import '../widgets/active_orders_widget.dart';

class TradeScreen extends ConsumerStatefulWidget {
  final String symbol;

  const TradeScreen({super.key, this.symbol = 'HPG'});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<StockData> _stockData = [];
  CompanyOverview? _companyOverview;
  Map<String, dynamic> _orderBook = {'bids': [], 'asks': []};
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedTimeframe = '1D';
  String _selectedResolution = '30m';
  bool _isBuyMode = true;
  late String _currentSymbol;
  
  // Order Form Controllers
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedOrderType = 'Lệnh giới hạn'; // Default to Limit Order

  // Realtime Data
  double? _realtimePrice;
  double? _realtimeChange;

  @override
  void initState() {
    super.initState();
    _currentSymbol = widget.symbol;
    _fetchData();
    _connectSocket();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _connectSocket() {
    _socketService.connect();
    _socketService.stream?.listen((message) {
      final data = _socketService.parseData(message);
      if (data != null && data['symbol'] == _currentSymbol) {
        setState(() {
          _realtimePrice = (data['price'] as num?)?.toDouble() ?? _realtimePrice;
          _realtimeChange = (data['change_percent'] as num?)?.toDouble() ?? _realtimeChange;
        });
      }
    });
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final now = DateTime.now();
      DateTime startDate;
      String resolution = '1D';

      switch (_selectedTimeframe) {
        case '1D':
          // Increase to 5 days to ensure we get at least 2-3 trading days for Stooq (Daily data)
          // even if there's a weekend. For Intraday (Yahoo/Binance), 5 days is a good "recent trend" view.
          startDate = now.subtract(const Duration(days: 5)); 
          resolution = _selectedResolution; 
          break;
        case '1W':
          startDate = now.subtract(const Duration(days: 7));
          resolution = '1H';
          break;
        case '1M':
          startDate = now.subtract(const Duration(days: 30));
          resolution = '1D';
          break;
        case '3M':
          startDate = now.subtract(const Duration(days: 90));
          resolution = '1D';
          break;
        case '1Y':
          startDate = now.subtract(const Duration(days: 365));
          resolution = '1D';
          break;
        case 'All':
          startDate = now.subtract(const Duration(days: 365 * 5));
          resolution = '1W';
          break;
        default:
          startDate = now.subtract(const Duration(days: 90));
      }

      final dateFormat = DateFormat('yyyy-MM-dd');

      final results = await Future.wait([
        _apiService.getStockHistory(
          _currentSymbol,
          dateFormat.format(startDate),
          dateFormat.format(now),
          resolution: resolution,
        ),
        _apiService.getCompanyOverview(_currentSymbol),
        _apiService.fetchOrderBook(_currentSymbol),
      ]);

      setState(() {
        final rawData = results[0] as List<StockData>;
        // Filter out invalid data points (where price is 0 due to missing data)
        _stockData = rawData.where((e) => e.close > 0 && e.open > 0).toList();
        _companyOverview = results[1] as CompanyOverview;
        _orderBook = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePlaceOrder() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đặt lệnh')),
      );
      return;
    }

    // --- Validation Logic ---
    final quantity = int.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text) ?? _realtimePrice ?? (_stockData.isNotEmpty ? _stockData.last.close : 0.0);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số lượng hợp lệ')));
      return;
    }

    // Check Balance / Holdings
    final portfolioAsync = ref.read(portfolioControllerProvider);
    if (portfolioAsync.hasValue) {
       final portfolio = portfolioAsync.value;
       
       if (_isBuyMode) {
          final totalCost = price * quantity;
          if ((portfolio?.portfolio?.balance ?? 0) < totalCost) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Số dư không đủ! (Cần: ${NumberFormat.simpleCurrency(name: 'VND').format(totalCost)})'), // Simple format
              backgroundColor: Colors.red,
            ));
            return;
          }
       } else {
          // Sell Mode: Check holdings
          final holding = portfolio?.portfolio?.holdings.firstWhere((h) => h.symbol == _currentSymbol, orElse: () => const HoldingEntity(symbol: '', quantity: 0, averagePrice: 0));
          if ((holding?.quantity ?? 0) < quantity) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Không đủ cổ phiếu để bán! (Có: ${holding?.quantity ?? 0})'),
              backgroundColor: Colors.red,
            ));
            return;
          }
       }
    }

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Giá không hợp lệ')));
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Call API to place order
      final result = await _apiService.placeOrder(
        user.uid,
        _currentSymbol,
        _isBuyMode ? 'buy' : 'sell',
        quantity,
        price,
        orderType: _selectedOrderType == 'Lệnh thị trường' ? 'market' : 'limit',
      );

      // 2. Client-side Update REMOVED
      // The backend now handles balance deduction and stock updates.
      // We just need to wait for the API success response.


      // Hide loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đặt lệnh thành công! ID: ${result['data']['order_id']}'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // --- SYNC FIX: Refresh Data ---
        // Force refresh Portfolio (Balance/Holdings) & Orders (History)
        // We use invalidate to force a re-fetch next time the providers are read/watched.
        ref.invalidate(portfolioControllerProvider);
        ref.invalidate(orderControllerProvider);
        
        // Clear inputs
        _quantityController.clear();
        if (_selectedOrderType == 'Lệnh giới hạn') {
           _priceController.clear();
        }
      }
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        final errorMsg = e.toString();
        // Check for Maintenance Mode error
        if (errorMsg.contains("bảo trì") || errorMsg.contains("503")) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.build_circle_outlined, color: Colors.orange),
                  SizedBox(width: 8),
                  Text("Bảo trì hệ thống", style: TextStyle(fontSize: 18)),
                ],
              ),
              content: const Text("Hệ thống đang tạm ngừng giao dịch để nâng cấp. Vui lòng quay lại sau!"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Đóng", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        } else {
          // Normal error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi đặt lệnh: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  void _showStockSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _StockSelectorModal(
          onSelect: (symbol) {
            setState(() {
              _currentSymbol = symbol;
            });
            Navigator.pop(context);
            _fetchData();
          },
        ),
      ),
    );
  }


  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildMenuItem(Icons.settings, 'Cài đặt')),
                  Expanded(child: _buildMenuItem(Icons.swap_horiz, 'Chuyển tiền')),
                  Expanded(child: _buildMenuItem(Icons.receipt_long, 'Giao dịch')),
                  Expanded(child: _buildMenuItem(Icons.currency_exchange, 'Chuyển đổi')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildMenuItem(Icons.info_outline, 'Thông tin')),
                  Expanded(child: _buildMenuItem(Icons.percent, 'Phí')),
                  Expanded(child: _buildMenuItem(Icons.star_border, 'Bỏ yêu thích')),
                  Expanded(child: _buildMenuItem(Icons.storefront, 'Thị trường')),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8);
    final cardColor = isDark ? const Color(0xFF1A2028) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111418).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: _showStockSelector,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _currentSymbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, 
                        size: 20, 
                        color: isDark ? Colors.white : Colors.black
                      ),
                    ],
                  ),
                  Text(
                    'Spot',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xFF9CABBA) : const Color(0xFF637588),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Lịch sử lệnh',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.candlestick_chart),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showMenu,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await _fetchData(showLoading: false);
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderStats(isDark),
                            SizedBox(
                              height: 300,
                              width: double.infinity,
                              child: StockChart(data: _stockData),
                            ),
                            _buildTimeframeSelector(theme, isDark),
                            const Divider(),
                            _buildOrderSection(isDark),
                            const Divider(),
                            ActiveOrdersWidget(symbol: _currentSymbol),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
    );
  }

  Widget _buildHeaderStats(bool isDark) {
    if (_stockData.isEmpty) return const SizedBox();
    
    // Watch language
    final Locale locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');

    // Use realtime data if available, otherwise fallback to historical data
    final latestClose = _realtimePrice ?? _stockData.last.close;
    final percentChange = _realtimeChange ?? 
        ((_stockData.last.close - (_stockData.length > 1 ? _stockData[_stockData.length - 2].close : _stockData.last.close)) / 
        (_stockData.length > 1 ? _stockData[_stockData.length - 2].close : 1) * 100);
        
    final changeValue = latestClose * (percentChange / 100);
    final isPositive = percentChange >= 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                CurrencyHelper.format(latestClose, symbol: _currentSymbol, locale: locale),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? AppColors.success : AppColors.danger,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${CurrencyHelper.format(changeValue, symbol: _currentSymbol, locale: locale).replaceAll(RegExp(r'[^\d.,-]'), '')}', 
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${isPositive ? '+' : ''}${percentChange.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isPositive ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Cao: ${NumberFormat.compact().format(_stockData.last.high)}', style: const TextStyle(fontSize: 12)),
              Text('Thấp: ${NumberFormat.compact().format(_stockData.last.low)}', style: const TextStyle(fontSize: 12)),
              Text('KL: ${NumberFormat.compact().format(_stockData.last.volume)}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(bool isDark) {
    final activeColor = _isBuyMode ? AppColors.success : AppColors.danger;
    final inactiveColor = isDark ? Colors.grey[800] : Colors.grey[300];
    final inactiveTextColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Form (Left)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isBuyMode = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isBuyMode ? AppColors.success.withOpacity(0.8) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isBuyMode ? AppColors.success : Colors.grey.withOpacity(0.5),
                              width: _isBuyMode ? 0 : 1
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'MUA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isBuyMode ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isBuyMode = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isBuyMode ? AppColors.danger.withOpacity(0.8) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_isBuyMode ? AppColors.danger : Colors.grey.withOpacity(0.5),
                              width: !_isBuyMode ? 0 : 1
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'BÁN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isBuyMode ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedOrderType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                  ),
                  items: ['Lệnh thị trường', 'Lệnh giới hạn', 'Lệnh dừng'].map((e) {
                    return DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedOrderType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  enabled: _selectedOrderType == 'Lệnh giới hạn',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _selectedOrderType == 'Lệnh thị trường' ? 'Giá thị trường' : 'Giá đặt',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: _selectedOrderType == 'Lệnh thị trường' 
                      ? (_stockData.isNotEmpty 
                          // Watch language for hint text too? Hard to do inside build method without ref.watch if not rebuilt. 
                          // Since we're in ConsumerState, we can use ref.watch(language...).
                          // Assuming build method has access or we access via ref inside build.
                          // But we are in _buildOrderSection. We need to pass language in or watch it.
                          // Let's grab language at top of build.
                          ? 'Market Price' // Simplified as dynamic text is complex here.
                          : 'Loading...')
                      : 'Nhập giá',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Số lượng',
                    suffixText: _currentSymbol,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final portfolio = ref.watch(portfolioControllerProvider).valueOrNull;
                      final isBuy = _isBuyMode;
                      
                      String text;
                      if (isBuy) {
                         final balance = portfolio?.portfolio?.balance ?? 0;
                         // Format balance
                         text = "Saldo: ${NumberFormat.compact().format(balance)} VND";
                      } else {
                         final holding = portfolio?.portfolio?.holdings.firstWhere(
                           (h) => h.symbol == _currentSymbol, 
                           orElse: () => const HoldingEntity(symbol: '', quantity: 0, averagePrice: 0)
                         );
                         text = "Đang có: ${holding?.quantity ?? 0} CP";
                      }
                      
                      return Text(text, style: TextStyle(fontSize: 10, color: isBuy ? AppColors.success : Colors.orange));
                    }
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handlePlaceOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBuyMode ? AppColors.success.withOpacity(0.9) : AppColors.danger.withOpacity(0.9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2, // Slight elevation
                    ),
                    child: Text(
                      '${_isBuyMode ? "MUA" : "BÁN"} $_currentSymbol', 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Order Book (Right) - Placeholder for now
          Expanded(
            flex: 2,
            child: Container(
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Giá', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('SL', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                // Asks (Sells)
                ...(_orderBook['asks'] as List).reversed.take(5).map((e) => 
                  _buildOrderBookItem(
                    e['price'].toString(), 
                    e['quantity'].toString(), 
                    false
                  )
                ),
                if ((_orderBook['asks'] as List).isEmpty)
                  const Padding(padding: EdgeInsets.all(8.0), child: Text("- Empty -", style: TextStyle(fontSize: 10))),
                  
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Consumer( // Access language for this specific text
                     builder: (context, ref, _) {
                       final Locale locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
                       return Text(
                         _stockData.isNotEmpty 
                           ? CurrencyHelper.format(_stockData.last.close, symbol: _currentSymbol, locale: locale)
                           : '---',
                         style: const TextStyle(
                           color: AppColors.success,
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                         ),
                       );
                     }
                  ),
                ),
                
                // Bids (Buys)
                ...(_orderBook['bids'] as List).take(5).map((e) => 
                  _buildOrderBookItem(
                    e['price'].toString(), 
                    e['quantity'].toString(), 
                    true
                  )
                ),
                if ((_orderBook['bids'] as List).isEmpty)
                  const Padding(padding: EdgeInsets.all(8.0), child: Text("- Empty -", style: TextStyle(fontSize: 10))),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookItem(String price, String amount, bool isBuy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            price,
            style: TextStyle(
              color: isBuy ? AppColors.success : AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector(ThemeData theme, bool isDark) {
    final timeframes = ['1D', '1W', '1M', '3M', '1Y', 'All'];
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: timeframes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tf = timeframes[index];
              final isSelected = tf == _selectedTimeframe;
              return ChoiceChip(
                label: Text(tf == '1D' && isSelected ? '1D ▾' : tf),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeframe = tf;
                      if (tf == '1D' && _selectedResolution.isEmpty) {
                         _selectedResolution = '30m';
                      }
                    });
                    _fetchData();
                  }
                },
                backgroundColor: isDark ? const Color(0xFF1A2028) : Colors.white,
                selectedColor: AppColors.success,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppColors.success : (isDark ? const Color(0xFF3B4754) : const Color(0xFFDCE0E5)),
                  ),
                ),
                showCheckmark: false,
              );
            },
          ),
        ),
        if (_selectedTimeframe == '1D') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['1m', '5m', '15m', '30m', '1H'].map((res) {
                final isResSelected = res == _selectedResolution;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(res, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    selected: isResSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedResolution = res;
                        });
                        _fetchData();
                      }
                    },
                    backgroundColor: isDark ? Colors.transparent : Colors.grey[200],
                    selectedColor: AppColors.success.withOpacity(0.8),
                    labelStyle: TextStyle(
                      color: isResSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87),
                      fontWeight: isResSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isResSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ]
      ],
    );
  }
}

class _StockSelectorModal extends StatefulWidget {
  final Function(String) onSelect;

  const _StockSelectorModal({required this.onSelect});

  @override
  State<_StockSelectorModal> createState() => _StockSelectorModalState();
}

class _StockSelectorModalState extends State<_StockSelectorModal> {
  String _searchQuery = '';
  String _selectedTab = 'Spot';
  String _selectedFilter = 'Tất cả';

  final List<String> _tabs = ['Yêu thích', 'Spot', 'Futures', 'DEX', 'Quyền chọn'];
  final List<String> _filters = ['Tất cả', 'Hàng đầu', 'Nổi bật', 'Mới', 'AI'];

  final List<Map<String, dynamic>> _allStocks = [
    // VN Stocks
    {'symbol': 'HPG', 'name': 'Hòa Phát', 'change': '+2.5%', 'isUp': true, 'tags': ['Spot', 'Hàng đầu', 'Nổi bật']},
    {'symbol': 'VCB', 'name': 'Vietcombank', 'change': '-1.2%', 'isUp': false, 'tags': ['Spot', 'Hàng đầu']},
    {'symbol': 'FPT', 'name': 'FPT Corp', 'change': '+1.8%', 'isUp': true, 'tags': ['Spot', 'Nổi bật', 'AI']},
    {'symbol': 'VNM', 'name': 'Vinamilk', 'change': '-0.5%', 'isUp': false, 'tags': ['Spot', 'Hàng đầu']},
    {'symbol': 'MWG', 'name': 'Mobile World', 'change': '+2.4%', 'isUp': true, 'tags': ['Spot', 'Nổi bật']},
    {'symbol': 'TCB', 'name': 'Techcombank', 'change': '+0.9%', 'isUp': true, 'tags': ['Spot']},
    {'symbol': 'SSI', 'name': 'SSI Securities', 'change': '-1.5%', 'isUp': false, 'tags': ['Spot']},
    {'symbol': 'VHM', 'name': 'Vinhomes', 'change': '+0.5%', 'isUp': true, 'tags': ['Spot', 'Hàng đầu']},
    {'symbol': 'VIC', 'name': 'Vingroup', 'change': '-0.2%', 'isUp': false, 'tags': ['Spot']},
    {'symbol': 'MSN', 'name': 'Masan Group', 'change': '+1.1%', 'isUp': true, 'tags': ['Spot']},
    
    // US Stocks
    {'symbol': 'AAPL', 'name': 'Apple Inc.', 'change': '+0.8%', 'isUp': true, 'tags': ['Spot', 'Hàng đầu', 'Nổi bật', 'AI']},
    {'symbol': 'GOOG', 'name': 'Alphabet Inc.', 'change': '+1.2%', 'isUp': true, 'tags': ['Spot', 'Hàng đầu', 'AI']},
    {'symbol': 'MSFT', 'name': 'Microsoft', 'change': '+0.5%', 'isUp': true, 'tags': ['Spot', 'Hàng đầu', 'AI']},
    {'symbol': 'NVDA', 'name': 'NVIDIA', 'change': '+3.5%', 'isUp': true, 'tags': ['Spot', 'Nổi bật', 'AI']},
    {'symbol': 'TSLA', 'name': 'Tesla', 'change': '-2.1%', 'isUp': false, 'tags': ['Spot', 'Nổi bật']},
    {'symbol': 'AMZN', 'name': 'Amazon', 'change': '+0.3%', 'isUp': true, 'tags': ['Spot', 'Hàng đầu']},
    
    // Crypto / Indices
    {'symbol': 'BTC-USD', 'name': 'Bitcoin', 'change': '+1.5%', 'isUp': true, 'tags': ['Spot', 'Futures', 'Nổi bật']},
    {'symbol': 'ETH-USD', 'name': 'Ethereum', 'change': '-0.8%', 'isUp': false, 'tags': ['Spot', 'Futures']},
  ];

  List<Map<String, dynamic>> get _filteredStocks {
    return _allStocks.where((stock) {
      final matchesSearch = stock['symbol'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          stock['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesTab = _selectedTab == 'Spot' ? stock['tags'].contains('Spot') : 
                         _selectedTab == 'Futures' ? stock['tags'].contains('Futures') : true;

      bool matchesFilter = true;
      if (_selectedFilter != 'Tất cả') {
        matchesFilter = stock['tags'].contains(_selectedFilter);
      }
      
      return matchesSearch && matchesTab && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _tabs.map((tab) => _buildSelectorTab(tab)).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Sub-filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filters.map((filter) => _buildFilterChip(filter)).toList(),
            ),
          ),
          const Divider(),
          // Stock List
          Expanded(
            child: ListView.builder(
              itemCount: _filteredStocks.length,
              itemBuilder: (context, index) {
                final stock = _filteredStocks[index];
                return _buildStockListItem(
                  stock['symbol'],
                  stock['name'],
                  stock['change'],
                  stock['isUp'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTab(String title) {
    final isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = title;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2))
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(label),
          backgroundColor: isSelected
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300])
              : Colors.transparent,
          labelStyle: TextStyle(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                : Colors.grey,
            fontSize: 12,
          ),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildStockListItem(String symbol, String name, String change, bool isUp) {
    return ListTile(
      onTap: () => widget.onSelect(symbol),
      leading: Icon(Icons.star, color: Colors.amber, size: 20),
      title: Row(
        children: [
          Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('10x', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
      subtitle: Text(name),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // REMOVED: Mock price '12,345.00'
          // We can optionally show real price here if we fetch it, but for now just remove mock.
          Text(
            change,
            style: TextStyle(
              color: isUp ? AppColors.success : AppColors.danger,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

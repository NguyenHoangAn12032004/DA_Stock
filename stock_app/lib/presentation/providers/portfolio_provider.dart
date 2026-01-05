import 'dart:ui';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/portfolio_remote_datasource.dart';
import '../../data/repositories/portfolio_repository_impl.dart';
import '../../domain/entities/portfolio_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../../domain/usecases/get_portfolio_usecase.dart';
import 'auth_provider.dart';
import 'order_provider.dart'; 
import 'market_provider.dart';
import 'settings_provider.dart';
import '../../core/utils/currency_helper.dart';

part 'portfolio_provider.g.dart';

// --- Dependencies ---

@riverpod
PortfolioRemoteDataSource portfolioRemoteDataSource(PortfolioRemoteDataSourceRef ref) {
  return PortfolioRemoteDataSourceImpl(DioClient.instance);
}

@riverpod
PortfolioRepository portfolioRepository(PortfolioRepositoryRef ref) {
  return PortfolioRepositoryImpl(ref.watch(portfolioRemoteDataSourceProvider));
}

@riverpod
GetPortfolioUseCase getPortfolioUseCase(GetPortfolioUseCaseRef ref) {
  return GetPortfolioUseCase(ref.watch(portfolioRepositoryProvider));
}

// --- State Class ---

class PortfolioState {
  final PortfolioEntity? portfolio;
  final List<OrderEntity> orders;
  final double totalEquity;
  final double invested;
  final double cashBalance;
  final double totalPnL;
  final double totalPnLPercent;
  final Map<String, double> currentPrices;

  PortfolioState({
    this.portfolio,
    this.orders = const [],
    this.totalEquity = 0,
    this.invested = 0,
    this.cashBalance = 0,
    this.totalPnL = 0,
    this.totalPnLPercent = 0,
    this.currentPrices = const {},
  });

  PortfolioState copyWith({
    PortfolioEntity? portfolio,
    List<OrderEntity>? orders,
    double? totalEquity,
    double? invested,
    double? cashBalance,
    double? totalPnL,
    double? totalPnLPercent,
    Map<String, double>? currentPrices,
  }) {
    // Note: Use manual copyWith for simple fields, but for calculated ones, 
    // usually we don't pass them in copyWith unless we are overriding.
    // Here we just return new state with updated fields or existing.
    
    return PortfolioState(
      portfolio: portfolio ?? this.portfolio,
      orders: orders ?? this.orders,
      totalEquity: totalEquity ?? this.totalEquity,
      invested: invested ?? this.invested,
      cashBalance: cashBalance ?? this.cashBalance,
      totalPnL: totalPnL ?? this.totalPnL,
      totalPnLPercent: totalPnLPercent ?? this.totalPnLPercent,
      currentPrices: currentPrices ?? this.currentPrices,
    );
  }
}

@riverpod
Stream<PortfolioEntity> portfolioStream(PortfolioStreamRef ref) {
  // Use authStateChanges to ensure we have a user
  // Using 'read' for currentUser might be null on init, but stream keeps it alive?
  // Use authStateChanges provider to be reactive to login/logout
  return ref.watch(authStateChangesProvider.stream).asyncExpand((user) {
      if (user == null) return Stream.value(const PortfolioEntity(balance: 0, holdings: []));
      return ref.watch(portfolioRepositoryProvider).getPortfolioStream(user.id);
  });
}

// --- Controller ---

@riverpod
class PortfolioController extends _$PortfolioController {
  @override
  FutureOr<PortfolioState> build() async {
    // Watch Stream for Real-time Data
    // .future creates a Future that completes with the latest value
    // and rebuilds this provider whenever the stream emits.
    final portfolio = await ref.watch(portfolioStreamProvider.future);
    
    // Also fetch orders (optional: can stream them too if we wanted, but user asked for "Money")
    // Let's keep orders as one-shot or pull-to-refresh for now to save complexity, 
    // unless OrderProvider has stream?
    // User wants "Realtime Money". PortfolioEntity has balance.
    
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return PortfolioState(); // Should match authState logic

    final ordersFuture = ref.read(orderRepositoryProvider).getOrders(user.id);
    // Warning: Mixing Stream (Portfolio) and Future (Orders) in build.
    // If Stream updates, we re-fetch Orders. This is actually GOOD (synced).
    
    List<OrderEntity> orders = [];
    final ordersResult = await ordersFuture;
    ordersResult.fold(
      (l) => print('Orders fetch error: ${l.message}'),
      (r) => orders = r,
    );
     // ... rest of logic uses 'portfolio' variable directly ...
    
    // orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    // ...
    // Note: Variable 'portfolio' is now 'PortfolioEntity', not 'PortfolioEntity?'.
    // Logic below expects 'portfolio' to be possibly null or handled.
     
     if (user == null) { // Double check
       return PortfolioState();
     }
     
     // Continue with existing logic...


    // Sort orders descending
    orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Valid portfolio is guaranteed by stream default value
    // 2. Fetch Real-time Quotes for Holdings

    // 2. Fetch Real-time Quotes for Holdings
    final symbols = portfolio!.holdings.map((h) => h.symbol).toList();
    Map<String, double> currentPrices = {}; // Stores CONVERTED prices 
    Map<String, double> rawPrices = {}; // Stores RAW prices (for backup)

    if (symbols.isNotEmpty) {
       try {
         final quotesResult = await ref.read(marketRepositoryProvider).getRealtimeQuotes(symbols)
             .timeout(const Duration(seconds: 3));
             
         quotesResult.fold(
           (l) => print("Quotes error: $l"),
           (r) {
             for (var stock in r) {
               rawPrices[stock.symbol] = stock.price;
             }
           }
         );
       } catch (e) {
         print("Error fetching portfolio quotes (Timeout/Fail): $e");
         // Proceed with empty prices (or old rawPrices if we persisted state, but build is fresh)
       }
    }

    // 3. Calculate Real-time Equity & PnL (With FX Conversion)
    final Locale locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
    
    double invested = 0;
    double currentHoldingsValue = 0;

    for (var h in portfolio!.holdings) {
      // Convert Average Price (Cost)
      final avgPriceConverted = CurrencyHelper.convert(h.averagePrice, symbol: h.symbol, locale: locale);
      invested += h.quantity * avgPriceConverted;
      
      // Get Raw Price -> Convert
      final rawPrice = rawPrices[h.symbol] ?? h.averagePrice;
      final priceConverted = CurrencyHelper.convert(rawPrice, symbol: h.symbol, locale: locale);
      
      currentPrices[h.symbol] = priceConverted;
      currentHoldingsValue += h.quantity * priceConverted;
    }

    // Convert Cash
    // Cash is assumed 'VND' units (Local).
    final double cash = CurrencyHelper.convert(portfolio!.balance, symbol: 'VND', locale: locale);
    
    final double totalEquity = cash + currentHoldingsValue;
    
    // PnL (Unrealized)
    final double unrealizedPnL = currentHoldingsValue - invested;
    final double unrealizedPnLPercent = invested > 0 ? (unrealizedPnL / invested) * 100 : 0.0;

    // Use these for state
    return PortfolioState(
      portfolio: portfolio,
      orders: orders,
      cashBalance: cash,
      invested: invested,
      totalEquity: totalEquity, 
      totalPnL: unrealizedPnL,
      totalPnLPercent: unrealizedPnLPercent,
      currentPrices: currentPrices, // Now holds Converted Prices
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return build();
    });
  }
}

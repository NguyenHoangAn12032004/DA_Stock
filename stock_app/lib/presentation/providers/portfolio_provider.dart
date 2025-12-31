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

// --- Controller ---

@riverpod
class PortfolioController extends _$PortfolioController {
  @override
  FutureOr<PortfolioState> build() async {
    final user = await ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return PortfolioState();
    }

    // 1. Fetch Portfolio and Orders
    final portfolioFuture = ref.read(getPortfolioUseCaseProvider).call(user.id);
    final ordersFuture = ref.read(orderRepositoryProvider).getOrders(user.id);

    final results = await Future.wait([portfolioFuture, ordersFuture]);

    final portfolioResult = results[0] as dynamic; // Either<Failure, PortfolioEntity>
    final ordersResult = results[1] as dynamic;    // Either<Failure, List<OrderEntity>>

    PortfolioEntity? portfolio;
    List<OrderEntity> orders = [];

    portfolioResult.fold(
      (l) => print('Portfolio fetch error: ${l.message}'),
      (r) => portfolio = r,
    );

    ordersResult.fold(
      (l) => print('Orders fetch error: ${l.message}'),
      (r) => orders = r as List<OrderEntity>,
    );
    
    // Sort orders descending
    orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (portfolio == null) {
       return PortfolioState(orders: orders);
    }

    // 2. Fetch Real-time Quotes for Holdings
    final symbols = portfolio!.holdings.map((h) => h.symbol).toList();
    Map<String, double> currentPrices = {};

    if (symbols.isNotEmpty) {
       // We use the usecase from MarketProvider (imported via provider)
       // Need to import GetRealtimeQuotesUseCase provider or class
       // It's locally available in this file? No, we need to import it properly or use the one defined in market_provider.dart if exported.
       // Actually I can just read the repo or usecase directly if I inject it.
       // I need to add `import '../../presentation/providers/market_provider.dart';` or define the provider access here.
       // It seems `market_provider.dart` defines `getRealtimeQuotesUseCaseProvider`. Let's assume it's imported or I will add import.
       
       try {
         final quotesResult = await ref.read(marketRepositoryProvider).getRealtimeQuotes(symbols);
         quotesResult.fold(
           (l) => print("Quotes error: $l"),
           (r) {
             for (var stock in r) {
               currentPrices[stock.symbol] = stock.price;
             }
           }
         );
       } catch (e) {
         print("Error fetching portfolio quotes: $e");
       }
    }

    // 3. Calculate Real-time Equity & PnL
    double invested = 0;
    double currentHoldingsValue = 0;

    for (var h in portfolio!.holdings) {
      invested += h.quantity * h.averagePrice;
      
      final price = currentPrices[h.symbol] ?? h.averagePrice; // Fallback to avg if no quote
      currentHoldingsValue += h.quantity * price;
    }

    final double cash = portfolio!.balance;
    final double totalEquity = cash + currentHoldingsValue;
    final double totalPnL = totalEquity - (cash + invested); // (Cash + RealValue) - (Cash + Cost) = RealValue - Cost
    // Or simpler: currentHoldingsValue - invested.
    // Wait: Total PnL usually means PnL of the Portfolio. 
    // If I successfully sold, that profit is in Cash. 
    // So PnL is (CurrentEquity - InitialDeposit). But we don't track InitialDeposit.
    // We can only track "Unrealized PnL" of current holdings.
    // Let's stick to "Unrealized PnL" which is (CurrentHoldingsValue - CostOfHoldings).
    
    final double unrealizedPnL = currentHoldingsValue - invested;
    final double unrealizedPnLPercent = invested > 0 ? (unrealizedPnL / invested) * 100 : 0.0;

    // Use these for state
    return PortfolioState(
      portfolio: portfolio,
      orders: orders,
      cashBalance: cash,
      invested: invested,
      totalEquity: totalEquity, // Cash + Market Value of Stocks
      totalPnL: unrealizedPnL,
      totalPnLPercent: unrealizedPnLPercent,
      // We might want to pass currentPrices to UI to show per-stock value?
      // For now, UI calculates per-stock value? No, Entity doesn't have currentPrice.
      // We might need to enrich the HoldingEntity or pass a map. 
      // Let's just update the State to potentially include a map of prices? 
      // Or we assume the UI fetches quotes separately? No, better here.
      // For MVP, knowing the Total Equity is key. 
      // Individual items in UI might look "stale" (using avg price) if we don't update them.
      // Let's rely on MarketProvider's stream for the list items!
      // But the Total Header needs this calc.
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return build();
    });
  }
}

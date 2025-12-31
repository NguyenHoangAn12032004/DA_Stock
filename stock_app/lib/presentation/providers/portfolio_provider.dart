import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/portfolio_remote_datasource.dart';
import '../../data/repositories/portfolio_repository_impl.dart';
import '../../domain/entities/portfolio_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../../domain/usecases/get_portfolio_usecase.dart';
import 'auth_provider.dart';
import 'order_provider.dart'; // To access orderRepositoryProvider

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

  PortfolioState({
    this.portfolio,
    this.orders = const [],
    this.totalEquity = 0,
    this.invested = 0,
    this.cashBalance = 0,
    this.totalPnL = 0,
    this.totalPnLPercent = 0,
  });

  PortfolioState copyWith({
    PortfolioEntity? portfolio,
    List<OrderEntity>? orders,
  }) {
    // Recalculate derived values if inputs change
    final p = portfolio ?? this.portfolio;
    final o = orders ?? this.orders;
    
    if (p == null) return PortfolioState(orders: o);

    double calculatedInvested = 0;
    for (var h in p.holdings) {
      calculatedInvested += h.quantity * h.averagePrice;
    }
    
    final calculatedCash = p.balance;
    // Note: This uses averagePrice for 'current value' estimation if real-time price isn't merged yet.
    // In a real app, we would merge with MarketProvider's prices. 
    // For Phase 15 MVP, we keep it simple or assume holding.totalValue is updated by backend or we use avg functionality.
    // Let's assume holding.totalValue comes from backend or is 'current val'. 
    // If backend only gives avgPrice, then totalEquity ~ invested + cash (break even).
    // To show real PnL, we need real prices.
    
    // Let's rely on what the backend gives for holding.totalValue if available, else calc.
    // Assuming backend might not be updating totalValue with real-time market data yet.
    
    final calculatedTotalEquity = calculatedCash + calculatedInvested; // Simplification for now

    return PortfolioState(
      portfolio: p,
      orders: o,
      invested: calculatedInvested,
      cashBalance: calculatedCash,
      totalEquity: calculatedTotalEquity,
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

    // Parallel fetch
    final portfolioFuture = ref.read(getPortfolioUseCaseProvider).call(user.id);
    final ordersFuture = ref.read(orderRepositoryProvider).getOrders(user.id);

    final results = await Future.wait([portfolioFuture, ordersFuture]);

    final portfolioResult = results[0] as dynamic; // Either<Failure, PortfolioEntity>
    final ordersResult = results[1] as dynamic;    // Either<Failure, List<OrderEntity>>

    PortfolioEntity? portfolio;
    List<OrderEntity> orders = [];

    portfolioResult.fold(
      (l) => print('Portfolio fetch error: ${l.message}'), // Log or handle
      (r) => portfolio = r,
    );

    ordersResult.fold(
      (l) => print('Orders fetch error: ${l.message}'),
      (r) => orders = r as List<OrderEntity>,
    );
    
    // Sort orders descending
    orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return PortfolioState().copyWith(portfolio: portfolio, orders: orders);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return build();
    });
  }
}

import 'dart:async';
import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/chart_data_entity.dart';
import '../../domain/repositories/market_repository.dart';
import '../datasources/market_local_datasource.dart';
import '../datasources/market_remote_datasource.dart';

class MarketRepositoryImpl implements MarketRepository {
  final MarketRemoteDataSource _remoteDataSource;
  final MarketLocalDataSource _localDataSource;

  MarketRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<Either<Failure, List<StockEntity>>> getRealtimeQuotes(List<String> symbols) async {
    // Strategy: 
    // 1. Return Local Cache first (if available) -> This logic usually belongs to Presentation/Provider using AsyncValue.
    //    But here we requested a Future.
    // 2. Fetch Remote.
    // 3. Cache Remote.
    
    // Actually, for "Realtime Quotes", we usually want fresh data.
    // But we can try Local first to show *something*.
    // However, the signature returns just one either. 
    
    try {
      final remoteData = await _remoteDataSource.getInitialQuotes(symbols);
      await _localDataSource.cacheQuotes(remoteData);
      return Right(remoteData);
    } catch (e) {
      // If remote fails, try local
      try {
        final localData = await _localDataSource.getLastKnownQuotes();
        if (localData.isNotEmpty) {
           return Right(localData);
        }
        return Left(ServerFailure("No data available"));
      } catch (cacheError) {
        return Left(ServerFailure(e.toString()));
      }
    }
  }

  @override
  Stream<List<StockEntity>> get marketDataStream => _remoteDataSource.marketDataStream;

  @override
  Future<void> connectToMarketStream() async {
    await _remoteDataSource.connectStream();
  }

  @override
  Future<void> disconnectFromMarketStream() async {
    await _remoteDataSource.disconnectStream();
  }

  @override
  Future<Either<Failure, List<ChartDataEntity>>> getStockHistory(String symbol, String startDate, String endDate, {String resolution = '1D'}) async {
    try {
      // For history, we usually don't cache deeply in MVP yet, or we can cache by key "history_{symbol}_{res}".
      // For now, direct remote call.
      final result = await _remoteDataSource.getStockHistory(symbol, startDate, endDate, resolution: resolution);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

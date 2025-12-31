import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/stock_entity.dart';
import '../repositories/market_repository.dart';

class GetRealtimeQuotesUseCase {
  final MarketRepository _repository;

  GetRealtimeQuotesUseCase(this._repository);

  Future<Either<Failure, List<StockEntity>>> call(List<String> symbols) async {
    return await _repository.getRealtimeQuotes(symbols);
  }
}

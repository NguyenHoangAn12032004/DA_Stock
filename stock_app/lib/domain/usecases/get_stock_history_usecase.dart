import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/chart_data_entity.dart';
import '../repositories/market_repository.dart';

class GetStockHistoryUseCase {
  final MarketRepository _repository;

  GetStockHistoryUseCase(this._repository);

  Future<Either<Failure, List<ChartDataEntity>>> call(String symbol, String startDate, String endDate, {String resolution = '1D'}) async {
    return await _repository.getStockHistory(symbol, startDate, endDate, resolution: resolution);
  }
}

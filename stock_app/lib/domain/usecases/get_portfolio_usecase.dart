import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/portfolio_entity.dart';
import '../repositories/portfolio_repository.dart';

class GetPortfolioUseCase {
  final PortfolioRepository _repository;

  GetPortfolioUseCase(this._repository);

  Future<Either<Failure, PortfolioEntity>> call(String userId) async {
    return await _repository.getPortfolio(userId);
  }
}

import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/portfolio_entity.dart';

abstract class PortfolioRepository {
  Future<Either<Failure, PortfolioEntity>> getPortfolio(String userId);
  Stream<PortfolioEntity> getPortfolioStream(String userId);
}

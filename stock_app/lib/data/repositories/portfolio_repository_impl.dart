import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/portfolio_entity.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../datasources/portfolio_remote_datasource.dart';

class PortfolioRepositoryImpl implements PortfolioRepository {
  final PortfolioRemoteDataSource _remoteDataSource;

  PortfolioRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, PortfolioEntity>> getPortfolio(String userId) async {
    try {
      final result = await _remoteDataSource.getPortfolio(userId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

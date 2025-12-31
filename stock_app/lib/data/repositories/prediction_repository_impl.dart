import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/prediction_entity.dart';
import '../../domain/repositories/prediction_repository.dart';
import '../datasources/prediction_remote_datasource.dart';

class PredictionRepositoryImpl implements PredictionRepository {
  final PredictionRemoteDataSource _remoteDataSource;

  PredictionRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, PredictionEntity>> getPrediction(String symbol) async {
    try {
      final result = await _remoteDataSource.getPrediction(symbol);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_remote_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  final AlertRemoteDataSource _remoteDataSource;

  AlertRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, AlertEntity>> createAlert(AlertEntity alert) async {
    try {
      final result = await _remoteDataSource.createAlert(alert);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AlertEntity>>> getAlerts(String userId) async {
    try {
      final result = await _remoteDataSource.getAlerts(userId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAlert(String userId, String alertId) async {
    try {
      await _remoteDataSource.deleteAlert(userId, alertId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateAlert(String userId, String alertId, bool isActive) async {
    try {
      await _remoteDataSource.updateAlert(userId, alertId, isActive);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

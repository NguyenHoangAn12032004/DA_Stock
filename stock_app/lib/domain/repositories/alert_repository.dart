import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/alert_entity.dart';

abstract class AlertRepository {
  Future<Either<Failure, AlertEntity>> createAlert(AlertEntity alert);
  Future<Either<Failure, List<AlertEntity>>> getAlerts(String userId);
  Future<Either<Failure, void>> deleteAlert(String userId, String alertId);
  Future<Either<Failure, void>> updateAlert(String userId, String alertId, bool isActive);
}

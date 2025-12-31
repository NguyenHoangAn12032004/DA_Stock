import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/alert_entity.dart';
import '../repositories/alert_repository.dart';

class CreateAlertUseCase {
  final AlertRepository _repository;
  CreateAlertUseCase(this._repository);
  Future<Either<Failure, AlertEntity>> call(AlertEntity alert) => _repository.createAlert(alert);
}

class GetAlertsUseCase {
  final AlertRepository _repository;
  GetAlertsUseCase(this._repository);
  Future<Either<Failure, List<AlertEntity>>> call(String userId) => _repository.getAlerts(userId);
}

class DeleteAlertUseCase {
  final AlertRepository _repository;
  DeleteAlertUseCase(this._repository);
  Future<Either<Failure, void>> call(String userId, String alertId) => _repository.deleteAlert(userId, alertId);
}

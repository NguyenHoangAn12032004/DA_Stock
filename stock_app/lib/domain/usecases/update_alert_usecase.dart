import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../repositories/alert_repository.dart';

class UpdateAlertUseCase {
  final AlertRepository _repository;

  UpdateAlertUseCase(this._repository);

  Future<Either<Failure, void>> call(String userId, String alertId, bool isActive) {
    return _repository.updateAlert(userId, alertId, isActive);
  }
}

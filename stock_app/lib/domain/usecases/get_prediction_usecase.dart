import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/prediction_entity.dart';
import '../repositories/prediction_repository.dart';

class GetPredictionUseCase {
  final PredictionRepository _repository;

  GetPredictionUseCase(this._repository);

  Future<Either<Failure, PredictionEntity>> call(String symbol) async {
    return await _repository.getPrediction(symbol);
  }
}

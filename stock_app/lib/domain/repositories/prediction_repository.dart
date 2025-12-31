import '../../core/utils/either.dart';
import '../../core/errors/failures.dart';
import '../entities/prediction_entity.dart';

abstract class PredictionRepository {
  Future<Either<Failure, PredictionEntity>> getPrediction(String symbol);
}

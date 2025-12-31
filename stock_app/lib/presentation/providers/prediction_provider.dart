import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/prediction_remote_datasource.dart';
import '../../data/repositories/prediction_repository_impl.dart';
import '../../domain/entities/prediction_entity.dart';
import '../../domain/repositories/prediction_repository.dart';
import '../../domain/usecases/get_prediction_usecase.dart';

part 'prediction_provider.g.dart';

// --- Dependencies ---

@riverpod
PredictionRemoteDataSource predictionRemoteDataSource(PredictionRemoteDataSourceRef ref) {
  return PredictionRemoteDataSourceImpl(DioClient.instance);
}

@riverpod
PredictionRepository predictionRepository(PredictionRepositoryRef ref) {
  return PredictionRepositoryImpl(ref.watch(predictionRemoteDataSourceProvider));
}

@riverpod
GetPredictionUseCase getPredictionUseCase(GetPredictionUseCaseRef ref) {
  return GetPredictionUseCase(ref.watch(predictionRepositoryProvider));
}

// --- Controller ---

@riverpod
class PredictionController extends _$PredictionController {
  @override
  FutureOr<PredictionEntity?> build(String symbol) async {
    final useCase = ref.read(getPredictionUseCaseProvider);
    final result = await useCase(symbol);
    
    return result.fold(
      (failure) => null,
      (data) => data,
    );
  }
}


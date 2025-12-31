import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/prediction_entity.dart';

abstract class PredictionRemoteDataSource {
  Future<PredictionEntity> getPrediction(String symbol);
}

class PredictionRemoteDataSourceImpl implements PredictionRemoteDataSource {
  final DioClient _dioClient;

  PredictionRemoteDataSourceImpl(this._dioClient);

  @override
  Future<PredictionEntity> getPrediction(String symbol) async {
    try {
      final response = await _dioClient.dio.get('/api/predict/$symbol');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Parse action
        PredictionAction action;
        switch (data['action']?.toString().toUpperCase()) {
          case 'BUY': action = PredictionAction.buy; break;
          case 'SELL': action = PredictionAction.sell; break;
          default: action = PredictionAction.hold; break;
        }

        return PredictionEntity(
          symbol: data['symbol'],
          action: action,
          confidence: int.tryParse(data['confidence'].toString()) ?? 0,
          rationale: data['rationale'] ?? '',
          timestamp: int.tryParse(data['timestamp'].toString()) ?? 0,
        );
      } else {
        throw ServerFailure('Failed to fetch prediction: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

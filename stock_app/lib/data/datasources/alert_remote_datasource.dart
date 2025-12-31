import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/alert_entity.dart';

abstract class AlertRemoteDataSource {
  Future<AlertEntity> createAlert(AlertEntity alert);
  Future<List<AlertEntity>> getAlerts(String userId);
  Future<void> deleteAlert(String userId, String alertId);
  Future<void> updateAlert(String userId, String alertId, bool isActive);
}

class AlertRemoteDataSourceImpl implements AlertRemoteDataSource {
  final DioClient _dioClient;

  AlertRemoteDataSourceImpl(this._dioClient);

  @override
  Future<AlertEntity> createAlert(AlertEntity alert) async {
    try {
      final response = await _dioClient.dio.post('/api/alerts', data: {
        "user_id": alert.userId,
        "symbol": alert.symbol,
        "condition": alert.condition,
        "value": alert.value,
        "type": alert.type,
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return _mapJsonToEntity(data);
      } else {
        throw ServerFailure('Failed to create alert: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<AlertEntity>> getAlerts(String userId) async {
    try {
      final response = await _dioClient.dio.get('/api/alerts/$userId');
      if (response.statusCode == 200) {
        final List list = response.data['data'] ?? [];
        return list.map((e) => _mapJsonToEntity(e)).toList();
      } else {
        throw ServerFailure('Failed to fetch alerts: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteAlert(String userId, String alertId) async {
    try {
      final response = await _dioClient.dio.delete('/api/alerts/$userId/$alertId');
      if (response.statusCode != 200) {
        throw ServerFailure('Failed to delete alert: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateAlert(String userId, String alertId, bool isActive) async {
    try {
      final response = await _dioClient.dio.put(
        '/api/alerts/$userId/$alertId',
        data: {'is_active': isActive},
      );
      if (response.statusCode != 200) {
        throw ServerFailure('Failed to update alert: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  AlertEntity _mapJsonToEntity(Map<String, dynamic> json) {
    return AlertEntity(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      symbol: json['symbol'] ?? '',
      value: (json['value'] as num).toDouble(),
      condition: json['condition'] ?? '',
      type: json['type'] ?? 'Price',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? 0,
    );
  }
}

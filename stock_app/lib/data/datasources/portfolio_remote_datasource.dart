import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/holding_entity.dart';
import '../../domain/entities/portfolio_entity.dart';


abstract class PortfolioRemoteDataSource {
  Future<PortfolioEntity> getPortfolio(String userId);
  Stream<PortfolioEntity> getPortfolioStream(String userId);
}

class PortfolioRemoteDataSourceImpl implements PortfolioRemoteDataSource {
  final DioClient _dioClient;
  final FirebaseFirestore _firestore;

  PortfolioRemoteDataSourceImpl(this._dioClient, {FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<PortfolioEntity> getPortfolio(String userId) async {
      // Keep API for initial load or legacy support
      try {
        final response = await _dioClient.dio.get('/api/portfolio/$userId');
        if (response.statusCode == 200) {
           return _parsePortfolio(response.data);
        }
        throw ServerFailure('Failed to fetch portfolio');
      } catch (e) {
         // Fallback to Firestore if API fails? Or just throw.
         throw ServerFailure(e.toString());
      }
  }

  // Helper
  PortfolioEntity _parsePortfolio(Map<String, dynamic> data) {
      final double balance = (data['balance'] as num).toDouble();
      final List holdingsData = data['holdings'] ?? [];
      final holdings = holdingsData.map((h) => HoldingEntity(
        symbol: h['symbol'],
        quantity: int.tryParse(h['quantity'].toString()) ?? 0,
        averagePrice: (h['average_price'] as num).toDouble(),
      )).toList();
      return PortfolioEntity(balance: balance, holdings: holdings);
  }

  @override
  Stream<PortfolioEntity> getPortfolioStream(String userId) async* {
    yield* Stream.periodic(const Duration(seconds: 10))
      .asyncMap((_) => getPortfolio(userId));
  }
}

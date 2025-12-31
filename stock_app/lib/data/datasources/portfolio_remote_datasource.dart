import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/holding_entity.dart';
import '../../domain/entities/portfolio_entity.dart';

abstract class PortfolioRemoteDataSource {
  Future<PortfolioEntity> getPortfolio(String userId);
}

class PortfolioRemoteDataSourceImpl implements PortfolioRemoteDataSource {
  final DioClient _dioClient;

  PortfolioRemoteDataSourceImpl(this._dioClient);

  @override
  Future<PortfolioEntity> getPortfolio(String userId) async {
    try {
      final response = await _dioClient.dio.get('/api/portfolio/$userId');

      if (response.statusCode == 200) {
        final data = response.data;
        final double balance = (data['balance'] as num).toDouble();
        final List holdingsData = data['holdings'] ?? [];
        
        final holdings = holdingsData.map((h) => HoldingEntity(
          symbol: h['symbol'],
          quantity: int.tryParse(h['quantity'].toString()) ?? 0,
          averagePrice: (h['average_price'] as num).toDouble(),
        )).toList();

        return PortfolioEntity(balance: balance, holdings: holdings);
      } else {
        throw ServerFailure('Failed to fetch portfolio: ${response.statusCode}');
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

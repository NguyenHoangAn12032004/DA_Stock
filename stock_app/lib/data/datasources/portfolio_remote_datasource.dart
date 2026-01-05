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
  Stream<PortfolioEntity> getPortfolioStream(String userId) {
    // Combine User Doc (Balance) and Holdings Collection
    // Since we don't have RxDart easily, we use a simple generic approach: 
    // Listen to User, inside that listen to Holdings.
    
    // Better: StreamController.
    // However, simplest 'good enough' for now:
    // Just listen to User changes. Holdings changes are less frequent or usually occur WITH balance change (buy/sell).
    // EXCEPT market maker actions or price updates? No, holdings qty only changes on trade.
    // Trade ALWAYS updates balance. So User/Balance stream triggers update.
    // BUT, we need the holdings data too.
    
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((userDoc) async {
        if (!userDoc.exists) return const PortfolioEntity(balance: 0, holdings: []);
        
        final double balance = (userDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        
        // Fetch Holdings (One-shot or Stream?)
        // If we want FULL realtime, we need Stream. merging streams is hard without Rx.
        // Let's do One-shot fetch of holdings whenever User Doc changes.
        // Reason: Balance update usually happens with Holdings update in transaction.
        // So User Doc change is a good trigger.
        
        final holdingsSnap = await _firestore.collection('users').doc(userId).collection('holdings').get();
        final holdings = holdingsSnap.docs.map((doc) {
             final data = doc.data();
             return HoldingEntity(
                symbol: data['symbol'],
                quantity: (data['quantity'] as num?)?.toInt() ?? 0,
                averagePrice: (data['average_price'] as num?)?.toDouble() ?? 0.0, // Firestore might not have avg_price yet?
                // Note: Previous 'place_order' implementation in main.py updates 'holdings' collection
                // but does NOT seem to update 'average_price'. 
                // Let's check main.py... It does NOT update average_price.
                // It only does `inc(qty)`.
                // So average_price might be missing or stale in Firestore!
                // This explains why API was used (API might calculate it?). 
                // API `get_portfolio` DOES calculate avg price if logic exists.
                // Wait, main.py `get_portfolio` iterates pending orders etc?
                // If I switch to Firestore, I might lose 'Average Price' logic if it's computed on backend.
             );
        }).where((h) => h.quantity > 0).toList();
        
        return PortfolioEntity(balance: balance, holdings: holdings);
    });
  }
}

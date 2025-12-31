import 'package:fpdart/fpdart.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/portfolio_entity.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_remote_datasource.dart';

class AiRepositoryImpl implements AiRepository {
  final AiRemoteDataSource remoteDataSource;

  AiRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, String>> sendMessage(String symbol, String message) async {
    try {
      final result = await remoteDataSource.chat(symbol, message);
      return Right(result);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> analyzePortfolio(PortfolioEntity portfolio, double totalEquity, double cashBalance) async {
    try {
      // Construct Prompt
      final buffer = StringBuffer();
      buffer.writeln("Please analyze my portfolio:");
      buffer.writeln("Total Equity: \$${totalEquity.toStringAsFixed(2)}");
      buffer.writeln("Cash Balance: \$${cashBalance.toStringAsFixed(2)}");
      buffer.writeln("Holdings:");
      
      for (var h in portfolio.holdings) {
        buffer.writeln("- ${h.symbol}: ${h.quantity} shares (Avg: ${h.averagePrice})");
      }
      
      buffer.writeln("\nProvide a risk assessment and diversification advice.");
      
      final result = await remoteDataSource.analyzePortfolio(buffer.toString());
      return Right(result);
    } catch (e) {
      if (e is Failure) return Left(e);
      return Left(ServerFailure(e.toString()));
    }
  }
}

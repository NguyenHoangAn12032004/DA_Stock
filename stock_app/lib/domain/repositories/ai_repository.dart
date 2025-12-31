import 'package:fpdart/fpdart.dart';
import '../../core/errors/failures.dart';
import '../entities/portfolio_entity.dart';

abstract class AiRepository {
  Future<Either<Failure, String>> sendMessage(String symbol, String message);
  Future<Either<Failure, String>> analyzePortfolio(PortfolioEntity portfolio, double totalEquity, double cashBalance);
}

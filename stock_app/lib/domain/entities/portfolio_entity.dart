import 'package:equatable/equatable.dart';
import 'holding_entity.dart';

class PortfolioEntity extends Equatable {
  final double balance;
  final List<HoldingEntity> holdings;

  const PortfolioEntity({
    required this.balance,
    required this.holdings,
  });

  @override
  List<Object?> get props => [balance, holdings];
}

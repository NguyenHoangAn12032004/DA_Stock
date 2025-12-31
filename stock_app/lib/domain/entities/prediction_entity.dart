import 'package:equatable/equatable.dart';

enum PredictionAction { buy, sell, hold }

class PredictionEntity extends Equatable {
  final String symbol;
  final PredictionAction action;
  final int confidence;
  final String rationale;
  final int timestamp;

  const PredictionEntity({
    required this.symbol,
    required this.action,
    required this.confidence,
    required this.rationale,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [symbol, action, confidence, rationale, timestamp];
}

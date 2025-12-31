import 'package:equatable/equatable.dart';

class ChartDataEntity extends Equatable {
  final DateTime time; // Use DateTime for X-axis
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  const ChartDataEntity({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  @override
  List<Object?> get props => [time, open, high, low, close, volume];
}

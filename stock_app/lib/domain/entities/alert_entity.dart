import 'package:equatable/equatable.dart';

class AlertEntity extends Equatable {
  final String id;
  final String userId;
  final String symbol;
  final double value;
  final String condition; // "Above", "Below"
  final String type; // "Price"
  final bool isActive;
  final int createdAt;

  const AlertEntity({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.value,
    required this.condition,
    this.type = 'Price',
    this.isActive = true,
    required this.createdAt,
  });

  AlertEntity copyWith({
    String? id,
    String? userId,
    String? symbol,
    double? value,
    String? condition,
    String? type,
    bool? isActive,
    int? createdAt,
  }) {
    return AlertEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      symbol: symbol ?? this.symbol,
      value: value ?? this.value,
      condition: condition ?? this.condition,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, symbol, value, condition, type, isActive, createdAt];
}

import 'position.dart';

class Portfolio {
  final double usdt;
  final double deposits;
  final double realized;
  final Map<String, Position> positions;

  const Portfolio({
    required this.usdt,
    required this.deposits,
    required this.realized,
    required this.positions,
  });

  Portfolio copyWith({
    double? usdt,
    double? deposits,
    double? realized,
    Map<String, Position>? positions,
  }) {
    return Portfolio(
      usdt: usdt ?? this.usdt,
      deposits: deposits ?? this.deposits,
      realized: realized ?? this.realized,
      positions: positions ?? Map.from(this.positions),
    );
  }

  double calculateEquity(Map<String, double> currentPrices) {
    double coinValue = 0.0;
    for (final entry in positions.entries) {
      final base = entry.key;
      final position = entry.value;
      final currentPrice = currentPrices[base] ?? 0.0;
      coinValue += position.qty * currentPrice;
    }
    return usdt + coinValue;
  }

  double calculateTotalCoinValue(Map<String, double> currentPrices) {
    double total = 0.0;
    for (final entry in positions.entries) {
      final base = entry.key;
      final position = entry.value;
      final currentPrice = currentPrices[base] ?? 0.0;
      total += position.qty * currentPrice;
    }
    return total;
  }

  double calculateTotalUnrealized(Map<String, double> currentPrices) {
    double total = 0.0;
    for (final entry in positions.entries) {
      final base = entry.key;
      final position = entry.value;
      if (position.qty > 0) {
        final currentPrice = currentPrices[base] ?? 0.0;
        total += (currentPrice - position.avgEntry) * position.qty;
      }
    }
    return total;
  }

  double calculateNetReturnPercent(Map<String, double> currentPrices) {
    if (deposits == 0.0) return 0.0;
    final equity = calculateEquity(currentPrices);
    return ((equity - deposits) / deposits) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'usdt': usdt,
      'deposits': deposits,
      'realized': realized,
      'positions': positions.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  factory Portfolio.fromJson(Map<String, dynamic> json) {
    final positionsJson = json['positions'] as Map<String, dynamic>? ?? {};
    return Portfolio(
      usdt: (json['usdt'] as num?)?.toDouble() ?? 0.0,
      deposits: (json['deposits'] as num?)?.toDouble() ?? 0.0,
      realized: (json['realized'] as num?)?.toDouble() ?? 0.0,
      positions: positionsJson.map(
        (key, value) => MapEntry(key, Position.fromJson(value)),
      ),
    );
  }
}

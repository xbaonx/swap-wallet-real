enum TradeSide { buy, sell }

class TradeRecord {
  final String id;
  final int timestamp;
  final String base;
  final TradeSide side;
  final double qty;
  final double price;
  final double feeRate;
  final double feePaid;
  final double proceeds;
  final double? realizedPnL;

  const TradeRecord({
    required this.id,
    required this.timestamp,
    required this.base,
    required this.side,
    required this.qty,
    required this.price,
    required this.feeRate,
    required this.feePaid,
    required this.proceeds,
    this.realizedPnL,
  });

  factory TradeRecord.buy({
    required String base,
    required double qty,
    required double price,
    required double feeRate,
    required double usdtIn,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '$timestamp-$base-buy';
    final feePaid = usdtIn * feeRate;
    
    return TradeRecord(
      id: id,
      timestamp: timestamp,
      base: base,
      side: TradeSide.buy,
      qty: qty,
      price: price,
      feeRate: feeRate,
      feePaid: feePaid,
      proceeds: -usdtIn,
      realizedPnL: null,
    );
  }

  factory TradeRecord.sell({
    required String base,
    required double qty,
    required double price,
    required double feeRate,
    required double usdtOut,
    required double realizedPnL,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '$timestamp-$base-sell';
    final feePaid = qty * price * feeRate;
    
    return TradeRecord(
      id: id,
      timestamp: timestamp,
      base: base,
      side: TradeSide.sell,
      qty: qty,
      price: price,
      feeRate: feeRate,
      feePaid: feePaid,
      proceeds: usdtOut,
      realizedPnL: realizedPnL,
    );
  }

  TradeRecord copyWith({
    String? id,
    int? timestamp,
    String? base,
    TradeSide? side,
    double? qty,
    double? price,
    double? feeRate,
    double? feePaid,
    double? proceeds,
    double? realizedPnL,
  }) {
    return TradeRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      base: base ?? this.base,
      side: side ?? this.side,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      feeRate: feeRate ?? this.feeRate,
      feePaid: feePaid ?? this.feePaid,
      proceeds: proceeds ?? this.proceeds,
      realizedPnL: realizedPnL ?? this.realizedPnL,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'base': base,
      'side': side.name,
      'qty': qty,
      'price': price,
      'feeRate': feeRate,
      'feePaid': feePaid,
      'proceeds': proceeds,
      'realizedPnL': realizedPnL,
    };
  }

  factory TradeRecord.fromJson(Map<String, dynamic> json) {
    return TradeRecord(
      id: json['id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      base: json['base'] as String? ?? '',
      side: TradeSide.values.firstWhere(
        (e) => e.name == json['side'],
        orElse: () => TradeSide.buy,
      ),
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      feeRate: (json['feeRate'] as num?)?.toDouble() ?? 0.0,
      feePaid: (json['feePaid'] as num?)?.toDouble() ?? 0.0,
      proceeds: (json['proceeds'] as num?)?.toDouble() ?? 0.0,
      realizedPnL: (json['realizedPnL'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TradeRecord(id: $id, base: $base, side: $side, qty: $qty, price: $price)';
  }
}

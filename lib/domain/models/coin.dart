class Coin {
  final String symbolPair;
  final String base;
  final double last;
  final double bid;
  final double ask;
  final double pct24h;
  final double quoteVolume;
  final List<double>? closes24h;

  const Coin({
    required this.symbolPair,
    required this.base,
    required this.last,
    required this.bid,
    required this.ask,
    required this.pct24h,
    required this.quoteVolume,
    this.closes24h,
  });

  Coin copyWith({
    String? symbolPair,
    String? base,
    double? last,
    double? bid,
    double? ask,
    double? pct24h,
    double? quoteVolume,
    List<double>? closes24h,
  }) {
    return Coin(
      symbolPair: symbolPair ?? this.symbolPair,
      base: base ?? this.base,
      last: last ?? this.last,
      bid: bid ?? this.bid,
      ask: ask ?? this.ask,
      pct24h: pct24h ?? this.pct24h,
      quoteVolume: quoteVolume ?? this.quoteVolume,
      closes24h: closes24h ?? this.closes24h,
    );
  }

  String get emoji {
    switch (base) {
      case 'BTC': return '₿';
      case 'ETH': return 'Ξ';
      case 'BNB': return '🟡';
      case 'ADA': return '🔷';
      case 'SOL': return '◎';
      case 'DOT': return '●';
      case 'DOGE': return '🐕';
      case 'AVAX': return '🔺';
      case 'LINK': return '🔗';
      case 'MATIC': return '💜';
      default: return '💰';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coin &&
          runtimeType == other.runtimeType &&
          symbolPair == other.symbolPair;

  @override
  int get hashCode => symbolPair.hashCode;
}

class Position {
  final double qty;
  final double avgEntry;

  const Position({
    required this.qty,
    required this.avgEntry,
  });

  Position copyWith({
    double? qty,
    double? avgEntry,
  }) {
    return Position(
      qty: qty ?? this.qty,
      avgEntry: avgEntry ?? this.avgEntry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qty': qty,
      'avgEntry': avgEntry,
    };
  }

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      qty: (json['qty'] as num).toDouble(),
      avgEntry: (json['avgEntry'] as num).toDouble(),
    );
  }

  bool get isEmpty => qty == 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          qty == other.qty &&
          avgEntry == other.avgEntry;

  @override
  int get hashCode => qty.hashCode ^ avgEntry.hashCode;
}

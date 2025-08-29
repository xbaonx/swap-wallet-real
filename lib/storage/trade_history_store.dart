import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/trade.dart';

class TradeHistoryStore {
  static const int maxTrades = 200;
  static const String _keyTrades = 'trades';
  
  final List<TradeRecord> _trades = [];

  List<TradeRecord> get trades => List.unmodifiable(_trades);

  void loadFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_keyTrades);
    _trades.clear();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      final List<dynamic> list = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> ? (decoded['trades'] as List<dynamic>? ?? const []) : const []);
      _trades.addAll(list.map((e) => TradeRecord.fromJson(e as Map<String, dynamic>)));
      if (_trades.length > maxTrades) {
        _trades.removeRange(0, _trades.length - maxTrades);
      }
    } catch (e) {
      dev.log('Error loading trades: $e');
      _trades.clear();
    }
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    try {
      final tradesJson = jsonEncode(_trades.map((trade) => trade.toJson()).toList());
      await prefs.setString(_keyTrades, tradesJson);
    } catch (e) {
      dev.log('Error saving trades: $e');
    }
  }

  void add(TradeRecord trade) {
    _trades.add(trade);
    
    // Maintain circular buffer - remove oldest if exceeding max
    if (_trades.length > maxTrades) {
      _trades.removeAt(0);
    }
  }

  void clear() {
    _trades.clear();
  }

  String exportJson() {
    try {
      final Map<String, dynamic> export = {
        'trades': _trades.map((trade) => trade.toJson()).toList(),
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        'count': _trades.length,
      };
      return jsonEncode(export);
    } catch (e) {
      dev.log('Error exporting trades: $e');
      return '{"trades":[],"exportedAt":0,"count":0}';
    }
  }

  void importJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> tradesList = data['trades'] as List<dynamic>? ?? [];
      
      _trades.clear();
      _trades.addAll(
        tradesList.map((json) => TradeRecord.fromJson(json)).toList(),
      );
      
      // Cap to max trades, keeping most recent
      if (_trades.length > maxTrades) {
        // Sort by timestamp descending, take most recent
        _trades.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final recentTrades = _trades.take(maxTrades).toList();
        _trades.clear();
        _trades.addAll(recentTrades);
        // Sort back to chronological order
        _trades.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    } catch (e) {
      dev.log('Error importing trades: $e');
      // Don't clear existing trades on import error
    }
  }

  List<TradeRecord> getRecentTrades(int limit) {
    if (_trades.isEmpty) return [];
    
    final sortedTrades = List<TradeRecord>.from(_trades);
    sortedTrades.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return sortedTrades.take(limit).toList();
  }

  List<TradeRecord> getTradesForBase(String base) {
    return _trades.where((trade) => trade.base == base).toList();
  }

  double getTotalRealizedPnL() {
    return _trades
        .where((trade) => trade.realizedPnL != null)
        .fold(0.0, (sum, trade) => sum + trade.realizedPnL!);
  }

  int getTotalTradeCount() => _trades.length;

  int getBuyCount() => _trades.where((trade) => trade.side == TradeSide.buy).length;

  int getSellCount() => _trades.where((trade) => trade.side == TradeSide.sell).length;
}

import 'dart:async';
import 'dart:developer' as dev;
import '../core/constants.dart';
import '../domain/models/coin.dart';
import 'binance_client.dart';
import 'token/token_registry.dart';

class RankingService {
  final BinanceClient _client = BinanceClient();
  final StreamController<List<Coin>> _rankingController = StreamController<List<Coin>>.broadcast();
  Timer? _refreshTimer;
  List<Coin> _currentTop50 = [];
  TokenRegistry? _tokenRegistry;
  bool _isRefreshing = false;
  DateTime? _lastRefreshAt;
  static const Duration _minManualRefreshInterval = Duration(seconds: 5);

  Stream<List<Coin>> get top50Stream => _rankingController.stream;
  List<Coin> get currentTop50 => List.unmodifiable(_currentTop50);

  Future<void> start({TokenRegistry? tokenRegistry}) async {
    _tokenRegistry = tokenRegistry;
    if (_refreshTimer != null) {
      dev.log('🔍 RANKING: start() called again — already started');
      return;
    }
    await _refreshRanking();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: AppConstants.rankingRefreshMinutes),
      (_) => _refreshRanking(),
    );
  }

  Future<void> refreshManually() async {
    final now = DateTime.now();
    if (_lastRefreshAt != null && now.difference(_lastRefreshAt!) < _minManualRefreshInterval) {
      dev.log('🔍 RANKING: Manual refresh debounced');
      return;
    }
    await _refreshRanking();
  }

  Future<void> _refreshRanking() async {
    if (_isRefreshing) {
      dev.log('🔍 RANKING: Refresh already in progress, skipping');
      return;
    }
    _isRefreshing = true;
    try {
      dev.log('🔍 RANKING: Starting refresh...');
      final stats24h = await _client.getAll24hStats();
      dev.log('🔍 RANKING: Got ${stats24h.length} symbols from Binance');
      
      final validCoins = <Coin>[];
      for (final entry in stats24h.entries) {
        final symbol = entry.key;
        final data = entry.value;
        
        if (_isValidUsdtPair(symbol)) {
          final base = symbol.substring(0, symbol.length - 4);
          
          // Only include tokens that exist on BSC (in TokenRegistry)
          if (_tokenRegistry != null && _tokenRegistry!.hasSymbol(base)) {
            validCoins.add(Coin(
              symbolPair: symbol,
              base: base,
              last: data['lastPrice'],
              bid: data['lastPrice'], // Will be updated by polling
              ask: data['lastPrice'], // Will be updated by polling
              pct24h: data['priceChangePercent'],
              quoteVolume: data['quoteVolume'],
            ));
          } else if (_tokenRegistry == null) {
            // Fallback when TokenRegistry not available
            validCoins.add(Coin(
              symbolPair: symbol,
              base: base,
              last: data['lastPrice'],
              bid: data['lastPrice'],
              ask: data['lastPrice'],
              pct24h: data['priceChangePercent'],
              quoteVolume: data['quoteVolume'],
            ));
          }
        }
      }

      validCoins.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));
      _currentTop50 = validCoins.take(AppConstants.top50Count).toList();
      
      dev.log('🔍 RANKING: Processed ${_currentTop50.length} BSC-compatible coins');
      if (_currentTop50.isNotEmpty) {
        dev.log('   Top coin: ${_currentTop50.first.base} vol=${_currentTop50.first.quoteVolume}');
      }
      if (_tokenRegistry != null) {
        dev.log('🔍 RANKING: Filtered using TokenRegistry (BSC tokens only)');
      }
      
      _rankingController.add(_currentTop50);
      dev.log('🔍 RANKING: Emitted to stream');
    } catch (e) {
      dev.log('Ranking refresh error: $e');
      // Emit empty list to unblock polling
      if (_currentTop50.isEmpty) {
        dev.log('🔍 RANKING: No cached data, emitting empty list');
        _rankingController.add([]);
      }
    } finally {
      _isRefreshing = false;
      _lastRefreshAt = DateTime.now();
    }
  }

  bool _isValidUsdtPair(String symbol) {
    return AppConstants.validUsdtPairRegex.hasMatch(symbol) &&
           !AppConstants.leveragedTokenRegex.hasMatch(symbol);
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _rankingController.close();
  }
}

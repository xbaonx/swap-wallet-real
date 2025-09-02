import 'dart:async';
import '../core/constants.dart';
import '../domain/models/coin.dart';
import 'binance_client.dart';
import 'ranking_service.dart';

class PollingService {
  final BinanceClient _client = BinanceClient();
  final RankingService _rankingService;
  final StreamController<List<Coin>> _coinsController = StreamController<List<Coin>>.broadcast();
  final Map<String, List<double>> _sparklineCache = {};
  final Map<String, DateTime> _sparklineCacheTime = {};
  
  Timer? _pollingTimer;
  bool _isPaused = false;
  bool _isOffline = false;
  List<Coin> _currentCoins = [];
  Set<String> _watchedPositions = <String>{};

  PollingService({RankingService? rankingService}) : _rankingService = rankingService ?? RankingService();

  Stream<List<Coin>> get coinsStream => _coinsController.stream;
  Stream<List<Coin>> get top50Stream => _rankingService.top50Stream;
  List<Coin> get currentCoins => List.unmodifiable(_currentCoins);
  bool get isOffline => _isOffline;

  void updateWatchedPositions(Set<String> positionBases) {
    _watchedPositions = positionBases;
  }

  Future<void> start() async {
    // Setup stream listener TRƯỚC khi start ranking service
    _rankingService.top50Stream.listen((coins) {
      _currentCoins = coins;
      _startPolling();
    });
    
    // Kiểm tra nếu đã có data từ cache
    final currentTop50 = _rankingService.currentTop50;
    if (currentTop50.isNotEmpty) {
      _currentCoins = currentTop50;
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (!_isPaused) {
      _pollingTimer = Timer.periodic(
        const Duration(seconds: AppConstants.pollingIntervalSeconds),
        (_) => _pollPrices(),
      );
      _pollPrices(); // Initial poll
    }
  }

  Future<void> _pollPrices() async {
    if (_isPaused || _currentCoins.isEmpty) return;

    try {
      final bookTickers = await _client.getAllBookTickers();
      final stats24h = await _client.getAll24hStats();
      
      // Create union of Top50 + watched positions
      final unionSymbols = <String>{};
      for (final coin in _currentCoins) {
        unionSymbols.add(coin.symbolPair);
      }
      for (final base in _watchedPositions) {
        unionSymbols.add('${base}USDT');
      }
      
      final updatedCoins = <Coin>[];
      final processedSymbols = <String>{};
      
      // Process existing Top50 coins
      for (final coin in _currentCoins) {
        final bookData = bookTickers[coin.symbolPair];
        final statsData = stats24h[coin.symbolPair];
        
        if (bookData != null && statsData != null) {
          updatedCoins.add(coin.copyWith(
            last: (bookData['bid'] + bookData['ask']) / 2,
            bid: bookData['bid'],
            ask: bookData['ask'],
            pct24h: statsData['priceChangePercent'],
            quoteVolume: statsData['quoteVolume'],
          ));
        } else {
          updatedCoins.add(coin);
        }
        processedSymbols.add(coin.symbolPair);
      }
      
      // Add watched positions not in Top50
      for (final base in _watchedPositions) {
        final symbol = '${base}USDT';
        if (!processedSymbols.contains(symbol)) {
          final bookData = bookTickers[symbol];
          final statsData = stats24h[symbol];
          
          if (bookData != null && statsData != null) {
            updatedCoins.add(Coin(
              symbolPair: symbol,
              base: base,
              last: (bookData['bid'] + bookData['ask']) / 2,
              bid: bookData['bid'],
              ask: bookData['ask'],
              pct24h: statsData['priceChangePercent'],
              quoteVolume: statsData['quoteVolume'],
            ));
          }
        }
      }
      
      _currentCoins = updatedCoins;
      _coinsController.add(_currentCoins);
      _isOffline = false;
    } catch (e) {
      _isOffline = true;
      // TODO: Handle polling error
    }
  }

  Future<List<double>> getSparklineData(String symbol) async {
    final now = DateTime.now();
    final cacheKey = symbol;
    
    if (_sparklineCache.containsKey(cacheKey) && _sparklineCacheTime[cacheKey] != null) {
      final cacheTime = _sparklineCacheTime[cacheKey]!;
      if (now.difference(cacheTime).inSeconds < AppConstants.sparklineCacheSeconds) {
        return _sparklineCache[cacheKey]!;
      }
    }

    try {
      final klines = await _client.getKlines(symbol);
      _sparklineCache[cacheKey] = klines;
      _sparklineCacheTime[cacheKey] = now;
      return klines;
    } catch (e) {
      return _sparklineCache[cacheKey] ?? [];
    }
  }

  Future<void> refreshRanking() async {
    await _rankingService.refreshManually();
  }

  void pause() {
    _isPaused = true;
    _pollingTimer?.cancel();
  }

  void resume() {
    _isPaused = false;
    _startPolling();
  }

  void stop() {
    _pollingTimer?.cancel();
    _rankingService.stop();
    _coinsController.close();
  }
}

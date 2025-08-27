import 'dart:async';
import 'dart:math';
import '../../core/constants.dart';
import '../../domain/models/coin.dart';
import '../../services/inch_client.dart';
import '../../data/token/token_registry.dart';
import '../../data/polling_service.dart';

/// Token info for hardcoded list
class TokenInfo {
  final String symbol;
  final String name;
  final String address;
  final int decimals;

  const TokenInfo({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
  });
}

/// Adapter that replaces PollingService and RankingService
/// Maintains identical API signatures while using 1inch data
class PricesAdapter extends PollingService {
  final InchClient _inchClient;
  final TokenRegistry _tokenRegistry;
  final StreamController<List<Coin>> _coinsController = StreamController<List<Coin>>.broadcast();
  final StreamController<List<Coin>> _rankingController = StreamController<List<Coin>>.broadcast();
  final Map<String, List<double>> _sparklineCache = {};
  final Map<String, DateTime> _sparklineCacheTime = {};
  final Map<String, Timer> _debounceTimers = {};
  
  // Rate limiting state
  DateTime _lastRateLimitTime = DateTime(0);
  int _consecutiveRateLimits = 0;
  int _requestsInLastMinute = 0;
  DateTime _lastMinuteReset = DateTime.now();
  static const int _maxRequestsPerMinute = 30;
  
  Timer? _pollingTimer;
  bool _isPaused = false;
  bool _isOffline = false;
  List<Coin> _currentCoins = [];
  List<Coin> _currentTop50 = [];
  Set<String> _watchedPositions = <String>{};


  // USDT address on BSC
  static const String _usdtAddress = '0x55d398326f99059ff775485246999027b3197955';
  static const int _usdtDecimals = 18;

  // Polling intervals - increased to avoid rate limits
  static const Duration _priceUpdateInterval = Duration(minutes: 2);
  static const Duration _rankingUpdateInterval = Duration(minutes: 30);
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  
  // Rate limiting constants - much higher delays to avoid bans
  static const Duration _baseDelay = Duration(milliseconds: 1500);
  static const int _maxRetries = 3;
  static const Duration _rateLimitCooldown = Duration(minutes: 5);

  PricesAdapter({
    required InchClient inchClient,
    required TokenRegistry tokenRegistry,
  })  : _inchClient = inchClient,
        _tokenRegistry = tokenRegistry,
        super();

  /// Stream of coins (replaces PollingService.coinsStream)
  @override
  Stream<List<Coin>> get coinsStream => _coinsController.stream;
  List<Coin> get currentCoins => List.unmodifiable(_currentCoins);
  bool get isOffline => _isOffline;

  /// Stream of top 50 coins (replaces RankingService.top50Stream)
  @override
  Stream<List<Coin>> get top50Stream => _rankingController.stream;
  List<Coin> get currentTop50 => List.unmodifiable(_currentTop50);

  void updateWatchedPositions(Set<String> positionBases) {
    _watchedPositions = positionBases;
    _scheduleUpdate();
  }

  Future<void> start() async {
    // Service starting

    // Skip warmup as TokenRegistry doesn't have this method

    final usdtAddr = _tokenRegistry.getTokenAddress('USDT');
    print('🧪 USDT address at start: ${usdtAddr ?? 'NULL'}');

    await _updateRanking(); // bắt buộc await để không emit rỗng trước

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_priceUpdateInterval, (_) => _updatePrices());

    Timer.periodic(_rankingUpdateInterval, (_) => _updateRanking());

    print('✅ PRICES ADAPTER: Started with ${_currentTop50.length} tokens');
  }

  /// Check if we should skip requests due to rate limiting
  bool _shouldSkipDueToRateLimit() {
    final now = DateTime.now();
    
    // Reset request counter every minute  
    if (now.difference(_lastMinuteReset).inMinutes >= 1) {
      _requestsInLastMinute = 0;
      _lastMinuteReset = now;
    }
    
    // Only skip if we're in active cooldown AND have high consecutive failures
    if (_consecutiveRateLimits >= 3) {
      final timeSinceLastRateLimit = now.difference(_lastRateLimitTime);
      if (timeSinceLastRateLimit < _rateLimitCooldown) {
        return true;
      }
      // Reset if cooldown period has passed
      _consecutiveRateLimits = 0;
    }
    
    // Allow more requests initially, only block if severely exceeded
    return _requestsInLastMinute >= (_maxRequestsPerMinute * 2);
  }
  
  /// Calculate exponential backoff delay based on consecutive failures
  Duration _calculateBackoffDelay(int retryCount) {
    final multiplier = pow(2, retryCount).toInt();
    final delayMs = _baseDelay.inMilliseconds * multiplier;
    final maxDelayMs = 30000; // Max 30 seconds
    return Duration(milliseconds: min(delayMs, maxDelayMs));
  }
  
  /// Handle rate limit response and update state
  void _handleRateLimit() {
    _lastRateLimitTime = DateTime.now();
    _consecutiveRateLimits++;
    print('⚠️ Rate limit hit. Consecutive: $_consecutiveRateLimits, entering cooldown for ${_rateLimitCooldown.inMinutes} minutes');
  }
  
  /// Track successful request
  void _trackRequest() {
    _requestsInLastMinute++;
    // Reset consecutive rate limits on successful request
    if (_consecutiveRateLimits > 0) {
      print('✅ Rate limit recovered after $_consecutiveRateLimits failures');
      _consecutiveRateLimits = 0;
    }
  }
  
  /// Make a quote request with retry and backoff logic
  Future<dynamic> _makeQuoteWithRetry({
    required String fromTokenAddress,
    required String toTokenAddress, 
    required String amountWei,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_shouldSkipDueToRateLimit()) {
      throw 'Rate limit: Skipping request to avoid API ban';
    }
    
    Exception? lastException;
    
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = _calculateBackoffDelay(attempt);
          print('🔄 Retry attempt $attempt after ${delay.inMilliseconds}ms delay');
          await Future.delayed(delay);
        }
        
        final quote = await _inchClient.quote(
          fromTokenAddress: fromTokenAddress,
          toTokenAddress: toTokenAddress,
          amountWei: amountWei,
        ).timeout(timeout);
        
        _trackRequest();
        return quote;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Check if this is a rate limit error
        if (e.toString().contains('429') || e.toString().toLowerCase().contains('rate limit')) {
          _handleRateLimit();
          // Don't retry immediately on rate limit, exit early
          throw 'Rate limited: ${e.toString()}';
        }
        
        // For other errors, continue with retries
        print('⚠️ Quote attempt $attempt failed: $e');
        
        // Don't retry on timeout or null response errors
        if (e.toString().contains('TimeoutException') || 
            e.toString().contains('null') ||
            e.toString().contains('zero out')) {
          break;
        }
      }
    }
    
    throw lastException ?? Exception('All retry attempts failed');
  }

  void _emitFallbackAndMarkOffline() {
    _isOffline = true;
    print('🔍 PRICES ADAPTER: Network error, no fallback data - using Binance for prices');
    // No hardcoded fallback - let Binance handle price display
    _currentTop50 = [];
    _currentCoins = [];
    if (!_rankingController.isClosed) _rankingController.add(_currentTop50);
    if (!_coinsController.isClosed) _coinsController.add(_currentCoins);
  }

  Future<void> _updateRanking() async {
    if (_isPaused) return;
    
    // This adapter is no longer used for price display - Binance handles that
    // Only maintain minimal functionality for swap operations if needed
    print('🔍 PRICES ADAPTER: Ranking update skipped - using Binance for price data');
  }

  Future<void> _updatePrices() async {
    if (_isPaused || _currentCoins.isEmpty) return;

    try {
      final updatedCoins = <Coin>[];
      final usdtAddress = _tokenRegistry.getTokenAddress('USDT');
      final usdtDecimals = _tokenRegistry.getTokenDecimals('USDT');
      if (usdtAddress == null || usdtDecimals == null) return;

      final amount10UsdtWei = (BigInt.from(10) * BigInt.from(10).pow(usdtDecimals)).toString();

      // Limit price updates to reduce memory pressure
      final symbolsToUpdate = <String>{};
      for (final coin in _currentCoins.take(5)) { // Limit to 5 coins max
        symbolsToUpdate.add(coin.base);
      }
      // Add watched positions but limit total
      symbolsToUpdate.addAll(_watchedPositions.take(3));

      int successCount = 0;
      for (final symbol in symbolsToUpdate) {
        if (successCount >= 3) break; // Max 3 successful updates per cycle
        
        final tokenAddress = _tokenRegistry.getTokenAddress(symbol);
        if (tokenAddress == null) continue;

        try {
          final decimals = _tokenRegistry.getTokenDecimals(symbol);
          
          // Use retry logic for price updates too
          final quote = await _makeQuoteWithRetry(
            fromTokenAddress: usdtAddress,
            toTokenAddress: tokenAddress,
            amountWei: amount10UsdtWei,
            timeout: const Duration(seconds: 6),
          );
          
          // Add null safety checks
          if (quote.toTokenAmount.isEmpty) {
            print('⚠️ Empty price response for $symbol');
            continue;
          }
          
          final outToken = BigInt.tryParse(quote.toTokenAmount);
          if (outToken == null || outToken == BigInt.zero) throw 'zero out';
          final tokenUnits = outToken / BigInt.from(10).pow(decimals);
          final price = 10.0 / tokenUnits.toDouble();
          
          if (price.isNaN || price.isInfinite || price <= 0) {
            throw 'invalid price: $price';
          }
          
          // Find existing coin or create new one
          final existingCoin = _currentCoins.where((c) => c.base == symbol).firstOrNull;
          final coin = existingCoin?.copyWith(
            last: price,
            bid: price * 0.999,
            ask: price * 1.001,
          ) ?? Coin(
            symbolPair: '${symbol}USDT',
            base: symbol,
            last: price,
            bid: price * 0.999,
            ask: price * 1.001,
            pct24h: 0.0,
            quoteVolume: _watchedPositions.contains(symbol) ? 0.0 : 1000000.0,
          );
          
          updatedCoins.add(coin);
          successCount++;
          
          // Adaptive delay based on rate limit state
          final delayMs = _consecutiveRateLimits > 0 ? 500 : 300;
          await Future.delayed(Duration(milliseconds: delayMs));
        } catch (e) {
          // Price update failed for $symbol
          
          // If rate limited, break early to avoid further API calls
          if (e.toString().contains('Rate limit') || e.toString().contains('429')) {
            // Breaking price update due to rate limit
            break;
          }
          
          // Keep old price if available
          final existingCoin = _currentCoins.where((c) => c.base == symbol).firstOrNull;
          if (existingCoin != null) {
            updatedCoins.add(existingCoin);
          }
        }
      }
      
      // Add remaining coins that weren't updated to maintain list
      for (final coin in _currentCoins) {
        if (!updatedCoins.any((c) => c.base == coin.base)) {
          updatedCoins.add(coin);
        }
      }
      
      _currentCoins = updatedCoins;
      
      // Only add to stream if controller is still open
      if (!_coinsController.isClosed) {
        _coinsController.add(_currentCoins);
      }
      
      // Only mark offline if we have very few working tokens (less than 5)
      _isOffline = _currentCoins.length < 5;
      
      // Updated prices successfully
    } catch (e) {
      // Only mark offline if we have no coins at all
      _isOffline = _currentCoins.isEmpty;
    }
  }

  void _scheduleUpdate() {
    // Debounce rapid calls to updateWatchedPositions
    _debounceTimers['update']?.cancel();
    _debounceTimers['update'] = Timer(_debounceDelay, () {
      if (!_isPaused) {
        _updatePrices();
      }
    });
  }

  // Original PollingService methods
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
      // Generate fake sparkline data based on current price
      final coin = _currentCoins.where((c) => c.base == symbol).firstOrNull;
      if (coin == null) return [];
      
      final basePrice = coin.last;
      final sparkline = <double>[];
      final random = Random();
      
      // Generate 24 hourly points with some volatility
      double currentPrice = basePrice * 0.95; // Start 5% lower
      for (int i = 0; i < 24; i++) {
        final change = (random.nextDouble() - 0.5) * 0.02; // ±1% max change
        currentPrice = currentPrice * (1 + change);
        sparkline.add(currentPrice);
      }
      
      _sparklineCache[cacheKey] = sparkline;
      _sparklineCacheTime[cacheKey] = now;
      return sparkline;
    } catch (e) {
      return _sparklineCache[cacheKey] ?? [];
    }
  }

  Future<void> refreshRanking() async {
    await _updateRanking();
  }

  void pause() {
    _isPaused = true;
    _pollingTimer?.cancel();
  }

  void resume() {
    _isPaused = false;
    if (_pollingTimer?.isActive != true) {
      _pollingTimer = Timer.periodic(_priceUpdateInterval, (_) => _updatePrices());
    }
  }

  void stop() {
    _pollingTimer?.cancel();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _coinsController.close();
    _rankingController.close();
  }
}

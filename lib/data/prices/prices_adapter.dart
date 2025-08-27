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

  // Token mapping for CoinGecko IDs
  static const Map<String, String> _coinGeckoIds = {
    'BNB': 'binancecoin',
    'CAKE': 'pancakeswap-token',
    'WETH': 'ethereum',
    'BTCB': 'bitcoin',
    'ADA': 'cardano',
    'DOT': 'polkadot',
    'UNI': 'uniswap',
    'LINK': 'chainlink',
    'LTC': 'litecoin',
    'XRP': 'ripple',
    'SHIB': 'shiba-inu',
    'AAVE': 'aave',
    'PEPE': 'pepe',
    'FLOKI': 'floki',
    'GALA': 'gala',
    '1INCH': '1inch',
    'MATIC': 'matic-network',
    'XVS': 'venus',
    'VAI': 'vai',
    'ALPACA': 'alpaca-finance',
    'BIFI': 'beefy-finance',
    'AUTO': 'autofarm',
    'AXS': 'axie-infinity',
    'SLP': 'smooth-love-potion',
    'TLM': 'alien-worlds',
    'SAFEMOON': 'safemoon-2',
    'BABYDOGE': 'baby-doge-coin',
    'DOGE': 'dogecoin',
    'FTM': 'fantom',
    'AVAX': 'avalanche-2',
  };

  // Hardcoded BSC tokens with verified addresses (kept for reference)
  static const List<TokenInfo> _top30Tokens = [
    // Native BSC tokens
    TokenInfo(symbol: 'BNB', name: 'BNB', address: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', decimals: 18),
    TokenInfo(symbol: 'CAKE', name: 'PancakeSwap Token', address: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82', decimals: 18),
    
    // Major bridged tokens on BSC
    TokenInfo(symbol: 'WETH', name: 'Wrapped Ether', address: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8', decimals: 18),
    TokenInfo(symbol: 'BTCB', name: 'Bitcoin BEP2', address: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c', decimals: 18),
    TokenInfo(symbol: 'ADA', name: 'Cardano Token', address: '0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47', decimals: 18),
    TokenInfo(symbol: 'DOT', name: 'Polkadot Token', address: '0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402', decimals: 18),
    TokenInfo(symbol: 'UNI', name: 'Uniswap', address: '0xBf5140A22578168FD562DCcF235E5D43A02ce9B1', decimals: 18),
    TokenInfo(symbol: 'LINK', name: 'ChainLink', address: '0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD', decimals: 18),
    TokenInfo(symbol: 'LTC', name: 'Litecoin Token', address: '0x4338665CBB7B2485A8855A139b75D5e34AB0DB94', decimals: 18),
    TokenInfo(symbol: 'XRP', name: 'XRP Token', address: '0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE', decimals: 18),
    
    // Popular BSC tokens
    TokenInfo(symbol: 'SHIB', name: 'SHIBA INU', address: '0x2859e4544C4bB03966803b044A93563Bd2D0DD4D', decimals: 18),
    TokenInfo(symbol: 'AAVE', name: 'Aave', address: '0xfb6115445Bff7b52FeB98650C87f44907E58f802', decimals: 18),
    TokenInfo(symbol: 'PEPE', name: 'Pepe', address: '0x25d887Ce7a35172C62FeBFD67a1856F20FaEbB00', decimals: 18),
    TokenInfo(symbol: 'FLOKI', name: 'FLOKI', address: '0xfb5B838b6cfEEdC2873aB27866079AC55363D37E', decimals: 9),
    TokenInfo(symbol: 'GALA', name: 'Gala', address: '0x7dDEE176F665cD201F93eEDE625770E2fD911990', decimals: 8),
    TokenInfo(symbol: '1INCH', name: '1inch', address: '0x111111111117dC0aa78b770fA6A738034120C302', decimals: 18),
    TokenInfo(symbol: 'MATIC', name: 'Polygon', address: '0xCC42724C6683B7E57334c4E856f4c9965ED682bD', decimals: 18),
    
    // DeFi tokens on BSC
    TokenInfo(symbol: 'XVS', name: 'Venus', address: '0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63', decimals: 18),
    TokenInfo(symbol: 'VAI', name: 'VAI Stablecoin', address: '0x4BD17003473389A42DAF6a0a729f6Fdb328BbBd7', decimals: 18),
    TokenInfo(symbol: 'ALPACA', name: 'Alpaca Finance', address: '0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F', decimals: 18),
    TokenInfo(symbol: 'BIFI', name: 'Beefy Finance', address: '0xCa3F508B8e4Dd382eE878A314789373D80A5190A', decimals: 18),
    TokenInfo(symbol: 'AUTO', name: 'AUTOv2', address: '0xa184088a740c695E156F91f5cC086a06bb78b827', decimals: 18),
    
    // Gaming tokens
    TokenInfo(symbol: 'AXS', name: 'Axie Infinity Shard', address: '0x715D400F88537EE1756193CCD8C2D5169B7cc25e', decimals: 18),
    TokenInfo(symbol: 'SLP', name: 'Smooth Love Potion', address: '0x070a08BeFCF6415f2CD7B88c5D6a84F2FF02f4Cf', decimals: 18),
    TokenInfo(symbol: 'TLM', name: 'Alien Worlds', address: '0x2222227E22102Fe3322098e4CBfE18cFebD57c95', decimals: 4),
    
    // Meme tokens
    TokenInfo(symbol: 'SAFEMOON', name: 'SafeMoon', address: '0x8076C74C5e3F5852037F31Ff0093Eeb8c8ADd8D3', decimals: 9),
    TokenInfo(symbol: 'BABYDOGE', name: 'Baby Doge Coin', address: '0xc748673057861a797275CD8A068AbB95A902e8de', decimals: 9),
    
    // Other popular tokens
    TokenInfo(symbol: 'DOGE', name: 'Dogecoin', address: '0xbA2aE424d960c26247Dd6c32edC70B295c744C43', decimals: 8),
    TokenInfo(symbol: 'FTM', name: 'Fantom Token', address: '0xAD29AbB318791D579433D831ed122aFeAf29dcfe', decimals: 18),
    TokenInfo(symbol: 'AVAX', name: 'Avalanche Token', address: '0x1CE0c2827e2eF14D5C4f29a091d735A204794041', decimals: 18),
  ];

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
    final fallbackCoins = <Coin>[
      Coin(symbolPair: 'BNBUSDT', base: 'BNB', last: 580.0, bid: 579.0, ask: 581.0, pct24h: 2.5, quoteVolume: 1000000.0),
      Coin(symbolPair: 'USDTUSDT', base: 'USDT', last: 1.0, bid: 0.999, ask: 1.001, pct24h: 0.0, quoteVolume: 2000000.0),
      Coin(symbolPair: 'USDCUSDT', base: 'USDC', last: 1.0, bid: 0.999, ask: 1.001, pct24h: 0.1, quoteVolume: 1500000.0),
      Coin(symbolPair: 'ETHUSDT', base: 'ETH', last: 3200.0, bid: 3195.0, ask: 3205.0, pct24h: 1.8, quoteVolume: 800000.0),
      Coin(symbolPair: 'CAKEUSDT', base: 'CAKE', last: 2.5, bid: 2.49, ask: 2.51, pct24h: -1.2, quoteVolume: 500000.0),
    ];
    _currentTop50 = fallbackCoins;
    _currentCoins = List.from(fallbackCoins);
    if (!_rankingController.isClosed) _rankingController.add(_currentTop50);
    if (!_coinsController.isClosed) _coinsController.add(_currentCoins);
  }

  Future<void> _updateRanking() async {
    if (_isPaused) return;

    try {
      final coins = <Coin>[];
      
      // Use CoinGecko batch API for all tokens in 1 request
      final coinGeckoIds = _coinGeckoIds.values.join(',');
      final url = 'https://api.coingecko.com/api/v3/simple/price?ids=$coinGeckoIds&vs_currencies=usd&include_24hr_change=true';
      
      final response = await _inchClient.httpClient.get(url);
      final priceData = response.data as Map<String, dynamic>;
      
      // Convert CoinGecko data to Coin objects
      for (final entry in _coinGeckoIds.entries) {
        final symbol = entry.key;
        final geckoId = entry.value;
        
        final tokenData = priceData[geckoId] as Map<String, dynamic>?;
        if (tokenData == null) continue;
        
        final price = (tokenData['usd'] as num?)?.toDouble() ?? 0.0;
        final change24h = (tokenData['usd_24h_change'] as num?)?.toDouble() ?? 0.0;
        
        if (price > 0) {
          coins.add(
            Coin(
              symbolPair: '${symbol}USDT',
              base: symbol,
              last: price,
              bid: price * 0.999,
              ask: price * 1.001,
              pct24h: change24h,
              quoteVolume: 1000000.0, // Dummy volume for UI sorting
            ),
          );
        }
      }

      // Only use fallback if we got very few results (less than 10)
      if (coins.length < 10) {
        _emitFallbackAndMarkOffline();
        return;
      }

      // Sort by price descending (highest to lowest)
      coins.sort((a, b) => b.last.compareTo(a.last));

      _currentTop50 = coins.take(50).toList();
      _currentCoins = List.from(_currentTop50);

      if (!_rankingController.isClosed) _rankingController.add(_currentTop50);
      if (!_coinsController.isClosed) _coinsController.add(_currentCoins);

      _isOffline = false;
      // Ranking updated successfully
    } catch (e) {
      _emitFallbackAndMarkOffline();
    }
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

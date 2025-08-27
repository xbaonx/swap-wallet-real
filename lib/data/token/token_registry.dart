import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/inch_client.dart';
import '../../services/models/oneinch_models.dart';
import '../../core/errors.dart';

class TokenInfo {
  final String symbol;
  final String name;
  final String address;
  final int decimals;
  final String? logoUri;

  const TokenInfo({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
    this.logoUri,
  });

  factory TokenInfo.fromOneInchToken(OneInchToken token) {
    return TokenInfo(
      symbol: token.symbol,
      name: token.name,
      address: token.address,
      decimals: token.decimals,
      logoUri: token.logoURI,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'address': address,
      'decimals': decimals,
      'logoUri': logoUri,
    };
  }

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      decimals: json['decimals'] as int,
      logoUri: json['logoUri'] as String?,
    );
  }
}

class TokenRegistry {
  final InchClient _inchClient;
  final SharedPreferences _prefs;
  
  Map<String, TokenInfo> _symbolToToken = {};
  Map<String, TokenInfo> _addressToToken = {};
  DateTime? _lastRefresh;
  
  static const String _cacheKey = 'token_registry_cache_v1';
  static const String _lastRefreshKey = 'token_registry_last_refresh';
  static const Duration _cacheExpiry = Duration(hours: 24);

  TokenRegistry({
    required InchClient inchClient,
    required SharedPreferences prefs,
  })  : _inchClient = inchClient,
        _prefs = prefs;

  /// Initialize the registry - loads from cache or fetches fresh data
  Future<void> initialize() async {
    await _loadFromCache();
    
    // If cache is expired or empty, fetch fresh data
    if (_isExpired() || _symbolToToken.isEmpty) {
      await refreshTokens();
    }
  }

  /// Get token by symbol (e.g., 'USDT', 'BNB')
  TokenInfo? getBySymbol(String symbol) {
    return _symbolToToken[symbol.toUpperCase()];
  }

  /// Get token by contract address
  TokenInfo? getByAddress(String address) {
    return _addressToToken[address.toLowerCase()];
  }

  /// Get all cached tokens
  List<TokenInfo> getAllTokens() {
    return _symbolToToken.values.toList();
  }

  /// Get popular tokens (first 50 by order in 1inch response)
  List<TokenInfo> getPopularTokens({int limit = 50}) {
    final tokens = getAllTokens();
    
    // If no tokens loaded from API, return hardcoded popular BSC tokens
    if (tokens.isEmpty) {
      return _getFallbackTokens().take(limit).toList();
    }
    
    return tokens.take(limit).toList();
  }
  
  /// Fallback tokens for when API is unavailable
  List<TokenInfo> _getFallbackTokens() {
    return [
      const TokenInfo(
        symbol: 'BNB',
        name: 'BNB',
        address: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'USDT',
        name: 'Tether USD',
        address: '0x55d398326f99059ff775485246999027b3197955',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'USDC',
        name: 'USD Coin',
        address: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'BUSD',
        name: 'BUSD Token',
        address: '0xe9e7cea3dedca5984780bafc599bd69add087d56',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'ETH',
        name: 'Ethereum Token',
        address: '0x2170ed0880ac9a755fd29b2688956bd959f933f8',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'CAKE',
        name: 'PancakeSwap Token',
        address: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'ADA',
        name: 'Cardano Token',
        address: '0x3ee2200efb3400fabb9aacf31297cbdd1d435d47',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'DOT',
        name: 'Polkadot Token',
        address: '0x7083609fce4d1d8dc0c979aab8c869ea2c873402',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'LINK',
        name: 'ChainLink Token',
        address: '0xf8a0bf9cf54bb92f17374d9e9a321e6a111a51bd',
        decimals: 18,
      ),
      const TokenInfo(
        symbol: 'UNI',
        name: 'Uniswap',
        address: '0xbf5140a22578168fd562dccf235e5d43a02ce9b1',
        decimals: 18,
      ),
    ];
  }

  /// Check if token exists by symbol
  bool hasSymbol(String symbol) {
    return _symbolToToken.containsKey(symbol.toUpperCase());
  }

  /// Check if token exists by address
  bool hasAddress(String address) {
    return _addressToToken.containsKey(address.toLowerCase());
  }

  /// Refresh tokens from 1inch API
  Future<void> refreshTokens() async {
    try {
      print('TokenRegistry: Fetching tokens from 1inch...');
      final response = await _inchClient.tokens();
      
      _symbolToToken.clear();
      _addressToToken.clear();
      
      for (final entry in response.tokens.entries) {
        final token = TokenInfo.fromOneInchToken(entry.value);
        _symbolToToken[token.symbol.toUpperCase()] = token;
        _addressToToken[token.address.toLowerCase()] = token;
      }
      
      _lastRefresh = DateTime.now();
      await _saveToCache();
      
      print('TokenRegistry: Cached ${_symbolToToken.length} tokens');
    } catch (e) {
      throw AppError.networkError('Failed to refresh tokens: $e');
    }
  }

  /// Force clear cache and refresh
  Future<void> clearCacheAndRefresh() async {
    await _prefs.remove(_cacheKey);
    await _prefs.remove(_lastRefreshKey);
    _symbolToToken.clear();
    _addressToToken.clear();
    _lastRefresh = null;
    await refreshTokens();
  }

  Future<void> _loadFromCache() async {
    try {
      final cacheJson = _prefs.getString(_cacheKey);
      final lastRefreshMs = _prefs.getInt(_lastRefreshKey);
      
      if (cacheJson != null && lastRefreshMs != null) {
        _lastRefresh = DateTime.fromMillisecondsSinceEpoch(lastRefreshMs);
        
        final cacheData = jsonDecode(cacheJson) as Map<String, dynamic>;
        final tokensData = cacheData['tokens'] as Map<String, dynamic>;
        
        _symbolToToken.clear();
        _addressToToken.clear();
        
        for (final entry in tokensData.entries) {
          final token = TokenInfo.fromJson(entry.value as Map<String, dynamic>);
          _symbolToToken[token.symbol.toUpperCase()] = token;
          _addressToToken[token.address.toLowerCase()] = token;
        }
        
        print('TokenRegistry: Loaded ${_symbolToToken.length} tokens from cache');
      }
    } catch (e) {
      print('TokenRegistry: Failed to load cache: $e');
      // Clear corrupted cache
      await _prefs.remove(_cacheKey);
      await _prefs.remove(_lastRefreshKey);
    }
  }

  Future<void> _saveToCache() async {
    try {
      final cacheData = {
        'tokens': _symbolToToken.map((symbol, token) => MapEntry(symbol, token.toJson())),
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      final cacheJson = jsonEncode(cacheData);
      await _prefs.setString(_cacheKey, cacheJson);
      await _prefs.setInt(_lastRefreshKey, _lastRefresh!.millisecondsSinceEpoch);
    } catch (e) {
      print('TokenRegistry: Failed to save cache: $e');
    }
  }

  bool _isExpired() {
    if (_lastRefresh == null) return true;
    return DateTime.now().difference(_lastRefresh!) > _cacheExpiry;
  }

  /// Helper methods for adapters
  String? getTokenAddress(String symbol) {
    final token = getBySymbol(symbol);
    if (token != null) return token.address;
    
    // Check fallback tokens
    final fallbackToken = _getFallbackTokens()
        .where((t) => t.symbol.toUpperCase() == symbol.toUpperCase())
        .firstOrNull;
    return fallbackToken?.address;
  }

  int getTokenDecimals(String symbol) {
    final token = getBySymbol(symbol);
    if (token != null) return token.decimals;
    
    // Check fallback tokens
    final fallbackToken = _getFallbackTokens()
        .where((t) => t.symbol.toUpperCase() == symbol.toUpperCase())
        .firstOrNull;
    return fallbackToken?.decimals ?? 18; // Default to 18 for ERC20
  }
}

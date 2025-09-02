import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../domain/models/portfolio.dart';
import '../domain/models/trade.dart';
import 'trade_history_store.dart';
import 'watchlist_store.dart';

class PrefsStore {
  final SharedPreferences _prefs;
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier(ThemeMode.system);
  // 'system' means follow device language; otherwise 'en' or 'vi'.
  final ValueNotifier<String> _languageNotifier = ValueNotifier('system');
  final ValueNotifier<Portfolio> _portfolioNotifier = ValueNotifier(
    const Portfolio(
      usdt: AppConstants.initialUsdt,
      deposits: AppConstants.initialDeposits,
      realized: 0.0,
      positions: {},
    ),
  );

  late final TradeHistoryStore _tradeHistoryStore;
  late final WatchlistStore _watchlistStore;
  
  Timer? _debounceTimer;
  bool _isInitialized = false;

  // Schema v2 keys
  static const _keySchema = 'schemaVersion';
  static const _keyThemeMode = 'themeMode';
  static const _keyPortfolio = 'portfolio';
  static const _keyLastTab = 'lastSelectedTab';
  static const _keyLanguage = 'languageCode';
  
  // Legacy v1 keys for migration
  static const _keyLegacyTheme = 'theme_mode';
  static const _keyLegacyWatchlist = 'watchlist';

  static const int _currentSchema = 2;
  static const int _debounceMs = 250;

  PrefsStore(this._prefs) {
    _tradeHistoryStore = TradeHistoryStore();
    _watchlistStore = WatchlistStore();
  }

  Future<void> _loadLanguage() async {
    final saved = _prefs.getString(_keyLanguage);
    if (saved == null || saved.isEmpty) {
      // No saved language -> follow system
      _languageNotifier.value = 'system';
    } else if (saved == 'system') {
      // Explicitly follow system
      _languageNotifier.value = 'system';
    } else {
      // Normalize explicit language code to 'en' or 'vi'
      _languageNotifier.value = _normalizeLang(saved);
    }
  }

  ValueListenable<ThemeMode> get themeMode => _themeModeNotifier;
  ValueListenable<String> get language => _languageNotifier;
  ValueListenable<Portfolio> get portfolio => _portfolioNotifier;
  TradeHistoryStore get tradeHistory => _tradeHistoryStore;
  WatchlistStore get watchlist => _watchlistStore;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _checkAndMigrateSchema();
    await _loadThemeMode();
    await _loadLanguage();
    await _loadPortfolio();
    _tradeHistoryStore.loadFromPrefs(_prefs);
    _watchlistStore.loadFromPrefs(_prefs);
    
    _setupListeners();
    _isInitialized = true;
  }

  Future<void> _checkAndMigrateSchema() async {
    final currentVersion = _prefs.getInt(_keySchema) ?? 1;
    
    if (currentVersion < _currentSchema) {
      await _migrateFromV1ToV2();
      await _prefs.setInt(_keySchema, _currentSchema);
    }
  }

  Future<void> _migrateFromV1ToV2() async {
    // Migrate theme from legacy key
    final legacyTheme = _prefs.getString(_keyLegacyTheme);
    if (legacyTheme != null && !_prefs.containsKey(_keyThemeMode)) {
      await _prefs.setString(_keyThemeMode, legacyTheme);
    }

    // Migrate portfolio - add updatedAt if missing
    final portfolioString = _prefs.getString(_keyPortfolio);
    if (portfolioString != null) {
      try {
        final json = jsonDecode(portfolioString) as Map<String, dynamic>;
        if (!json.containsKey('updatedAt')) {
          json['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
          await _prefs.setString(_keyPortfolio, jsonEncode(json));
        }
      } catch (e) {
        dev.log('Error migrating portfolio: $e');
      }
    }

    // Migrate legacy watchlist to new format
    final legacyWatchlist = _prefs.getStringList(_keyLegacyWatchlist);
    if (legacyWatchlist != null) {
      _watchlistStore.addAll(legacyWatchlist);
      await _watchlistStore.saveToPrefs(_prefs);
      await _prefs.remove(_keyLegacyWatchlist);
    }

    // Initialize default lastSelectedTab if not exists
    if (!_prefs.containsKey(_keyLastTab)) {
      await _prefs.setInt(_keyLastTab, 0);
    }
  }

  void _setupListeners() {
    _themeModeNotifier.addListener(_onThemeModeChanged);
    _portfolioNotifier.addListener(_onPortfolioChanged);
  }

  void _onThemeModeChanged() {
    _saveThemeMode(_themeModeNotifier.value);
  }

  void _onPortfolioChanged() {
    _debouncedSavePortfolio(_portfolioNotifier.value);
  }

  Future<void> _loadThemeMode() async {
    final themeModeString = _prefs.getString(_keyThemeMode) ?? 'system';
    switch (themeModeString) {
      case 'light':
        _themeModeNotifier.value = ThemeMode.light;
        break;
      case 'dark':
        _themeModeNotifier.value = ThemeMode.dark;
        break;
      default:
        _themeModeNotifier.value = ThemeMode.system;
    }
  }

  Future<void> _loadPortfolio() async {
    final portfolioString = _prefs.getString(_keyPortfolio);
    dev.log('🔍 DEBUG: Raw portfolio string from SharedPrefs: $portfolioString');
    
    if (portfolioString != null) {
      try {
        final json = jsonDecode(portfolioString) as Map<String, dynamic>;
        dev.log('🔍 DEBUG: Parsed portfolio JSON: $json');
        _portfolioNotifier.value = Portfolio.fromJson(json);
        dev.log('🔍 DEBUG: Portfolio loaded successfully - USDT: ${_portfolioNotifier.value.usdt}');
      } catch (e) {
        dev.log('Error loading portfolio: $e');
        await _savePortfolioImmediately(_portfolioNotifier.value);
      }
    } else {
      dev.log('🔍 DEBUG: No portfolio found in SharedPrefs - creating default');
      await _savePortfolioImmediately(_portfolioNotifier.value);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeModeNotifier.value = mode;
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await _prefs.setString(_keyThemeMode, modeString);
  }

  Future<void> setLanguage(String code) async {
    _languageNotifier.value = code;
    await _prefs.setString(_keyLanguage, code);
  }

  void savePortfolio(Portfolio portfolio) {
    _portfolioNotifier.value = portfolio;
  }

  void _debouncedSavePortfolio(Portfolio portfolio) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      _savePortfolioImmediately(portfolio);
    });
  }

  Future<void> _savePortfolioImmediately(Portfolio portfolio) async {
    try {
      final portfolioJson = portfolio.toJson();
      portfolioJson['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      final jsonString = jsonEncode(portfolioJson);
      await _prefs.setString(_keyPortfolio, jsonString);
    } catch (e) {
      dev.log('Error saving portfolio: $e');
    }
  }

  int getLastSelectedTab() {
    return _prefs.getInt(_keyLastTab) ?? 0;
  }

  Future<void> setLastSelectedTab(int index) async {
    await _prefs.setInt(_keyLastTab, index);
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    
    await Future.wait([
      _savePortfolioImmediately(_portfolioNotifier.value),
      _saveThemeMode(_themeModeNotifier.value),
      _tradeHistoryStore.saveToPrefs(_prefs),
      _watchlistStore.saveToPrefs(_prefs),
      _prefs.setInt(_keyLastTab, getLastSelectedTab()),
      _prefs.setString(_keyLanguage, _languageNotifier.value),
    ]);
  }

  String exportAll() {
    try {
      final Map<String, dynamic> export = {
        'schema': _currentSchema,
        'theme': _getThemeModeString(_themeModeNotifier.value),
        'portfolio': _addUpdatedAtToPortfolio(_portfolioNotifier.value.toJson()),
        'trades': _tradeHistoryStore.trades.map((trade) => trade.toJson()).toList(),
        'watchlist': _watchlistStore.bases.toList(),
        'lastSelectedTab': getLastSelectedTab(),
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
      };
      return jsonEncode(export);
    } catch (e) {
      dev.log('Error exporting data: $e');
      return '{}';
    }
  }

  Future<void> importAll(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final schema = data['schema'] as int? ?? 1;
      
      if (schema > _currentSchema) {
        throw Exception('Unsupported schema version: $schema');
      }

      // Import theme
      final themeString = data['theme'] as String?;
      if (themeString != null) {
        _themeModeNotifier.value = _parseThemeMode(themeString);
      }

      // Import portfolio
      final portfolioJson = data['portfolio'] as Map<String, dynamic>?;
      if (portfolioJson != null) {
        _portfolioNotifier.value = Portfolio.fromJson(portfolioJson);
      }

      // Import trades
      final tradesJson = data['trades'] as List<dynamic>?;
      if (tradesJson != null) {
        _tradeHistoryStore.importJson(jsonEncode({'trades': tradesJson}));
      }

      // Import watchlist
      final watchlistJson = data['watchlist'] as List<dynamic>?;
      if (watchlistJson != null) {
        _watchlistStore.importJson(jsonEncode({'watchlist': watchlistJson}));
      }

      // Import last selected tab
      final lastTab = data['lastSelectedTab'] as int?;
      if (lastTab != null) {
        await setLastSelectedTab(lastTab);
      }

      // Save everything
      await flush();
    } catch (e) {
      dev.log('Error importing data: $e');
      throw Exception('Failed to import data: $e');
    }
  }

  String _getThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _parseThemeMode(String modeString) {
    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> recordBuy({
    required String base,
    required double qty,
    required double price,
    required double feeRate,
    required double usdtIn,
  }) async {
    final rec = TradeRecord.buy(
      base: base, qty: qty, price: price, feeRate: feeRate, usdtIn: usdtIn);
    tradeHistory.add(rec);
    await tradeHistory.saveToPrefs(_prefs); // ghi ngay, không đợi flush
  }

  Future<void> recordSell({
    required String base,
    required double qty,
    required double price,
    required double feeRate,
    required double usdtOut,
    required double realizedPnL,
  }) async {
    final rec = TradeRecord.sell(
      base: base, qty: qty, price: price, feeRate: feeRate,
      usdtOut: usdtOut, realizedPnL: realizedPnL);
    tradeHistory.add(rec);
    await tradeHistory.saveToPrefs(_prefs); // ghi ngay
  }

  /// Lưu portfolio hiện tại và flush ngay (bỏ qua debounce).
  Future<void> commitNow(Portfolio p) async {
    _portfolioNotifier.value = p;
    _debounceTimer?.cancel();
    await _savePortfolioImmediately(p);
    await _saveThemeMode(_themeModeNotifier.value);
    await _tradeHistoryStore.saveToPrefs(_prefs);
    await _watchlistStore.saveToPrefs(_prefs);
  }

  /// Save current state when app goes to background
  Future<void> saveCurrentState() async {
    try {
      _debounceTimer?.cancel();
      await _savePortfolioImmediately(_portfolioNotifier.value);
      await _saveThemeMode(_themeModeNotifier.value);
      await _tradeHistoryStore.saveToPrefs(_prefs);
      await _watchlistStore.saveToPrefs(_prefs);
      dev.log('🔍 PREFS: Current state saved to disk');
    } catch (e) {
      dev.log('🔍 PREFS: Failed to save current state: $e');
    }
  }

  Map<String, dynamic> _addUpdatedAtToPortfolio(Map<String, dynamic> portfolioJson) {
    portfolioJson['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    return portfolioJson;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _themeModeNotifier.removeListener(_onThemeModeChanged);
    _portfolioNotifier.removeListener(_onPortfolioChanged);
    _themeModeNotifier.dispose();
    _languageNotifier.dispose();
    _portfolioNotifier.dispose();
  }

  // --- Language helpers ---
  static String _normalizeLang(String code) {
    if (code.toLowerCase().startsWith('vi')) return 'vi';
    return 'en';
  }
}

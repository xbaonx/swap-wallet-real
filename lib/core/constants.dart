class AppConstants {
  static const double tradingFee = 0.001; // 0.1%
  static const int pollingIntervalSeconds = 5;
  static const int rankingRefreshMinutes = 10;
  static const int sparklineCacheSeconds = 60;
  static const int top50Count = 50;
  static const double initialUsdt = 10000.0;
  static const double initialDeposits = 10000.0;
  
  static const String binanceBaseUrl = 'https://api.binance.com';
  static const String bookTickerEndpoint = '/api/v3/ticker/bookTicker';
  static const String stats24hEndpoint = '/api/v3/ticker/24hr';
  static const String klinesEndpoint = '/api/v3/klines';
  
  static const List<int> quickPercentages = [25, 50, 75, 100];
  static const int tradeHistoryLimit = 5;
  
  static RegExp get validUsdtPairRegex => RegExp(r'^[A-Z0-9]+USDT$');
  static RegExp get leveragedTokenRegex => RegExp(r'(UP|DOWN|BULL|BEAR)USDT$');
}

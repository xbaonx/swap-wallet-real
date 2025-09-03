import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/inch_client.dart';
import '../services/moralis_client.dart';
import '../services/config_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../onchain/wallet/wallet_service.dart';
import '../onchain/rpc/rpc_client.dart';
import '../data/token/token_registry.dart';
import '../data/prices/prices_adapter.dart';
import '../data/portfolio/portfolio_adapter.dart';
import '../onchain/swap/swap_adapter.dart';
import '../data/polling_service.dart';
import '../data/ranking_service.dart';

/// Service locator for dependency injection
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Core dependencies
  late SharedPreferences _prefs;
  late InchClient _inchClient;
  late MoralisClient _moralisClient;
  late ConfigService _configService;
  late WalletService _walletService;
  late RpcClient _rpcClient;
  late TokenRegistry _tokenRegistry;
  
  // Binance services (for charts and indicators)
  late PollingService _pollingService;
  late RankingService _rankingService;
  
  // App services
  late AnalyticsService _analyticsService;
  late NotificationService _notificationService;
  
  // 1inch adapters (for swap functionality)
  late PricesAdapter _pricesAdapter;
  late PortfolioAdapter _portfolioAdapter;
  late SwapAdapter _swapAdapter;

  bool _isInitialized = false;

  /// Initialize all services - call this in main()
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Initialize API clients
    _inchClient = InchClient();
    _moralisClient = MoralisClient();
    _configService = ConfigService();
    _analyticsService = AnalyticsService(prefs: _prefs);
    _notificationService = NotificationService();

    // Initialize blockchain services
    _walletService = WalletService();
    _rpcClient = RpcClient();

    // Initialize token registry
    _tokenRegistry = TokenRegistry(
      inchClient: _inchClient,
      prefs: _prefs,
    );
    await _tokenRegistry.initialize();

    // Initialize Binance services (for charts and indicators)  
    _rankingService = RankingService();
    _pollingService = PollingService(rankingService: _rankingService);

    // Initialize 1inch adapters (for swap functionality)
    _pricesAdapter = PricesAdapter(
      inchClient: _inchClient,
      tokenRegistry: _tokenRegistry,
    );

    _portfolioAdapter = PortfolioAdapter(
      moralisClient: _moralisClient,
      walletService: _walletService,
      tokenRegistry: _tokenRegistry,
    );

    _swapAdapter = SwapAdapter(
      inchClient: _inchClient,
      walletService: _walletService,
      rpcClient: _rpcClient,
      tokenRegistry: _tokenRegistry,
      portfolioAdapter: _portfolioAdapter,
    );

    _isInitialized = true;
    developer.log('All services initialized', name: 'locator');
    // Load runtime config at the end
    await _configService.refresh();
    // Fire a basic app start analytics event (non-blocking)
    try {
      await _analyticsService.track(eventName: 'app_start', props: {
        'env': dotenv.env['APP_ENV'] ?? 'production',
      });
    } catch (_) {}
  }

  /// Load wallet if exists and start portfolio sync
  Future<void> loadWalletIfExists() async {
    try {
      await _walletService.load();
      if (_walletService.isInitialized) {
        developer.log('Wallet loaded, syncing portfolio once', name: 'locator');
        // Sync once on wallet load, but don't start automatic periodic sync
        _portfolioAdapter.syncWithBlockchain();
        // Auto register device for notifications and track event
        try {
          final addr = await _walletService.getAddress();
          await _notificationService.registerDevice(walletAddress: addr);
          await _analyticsService.track(eventName: 'wallet_loaded', walletAddress: addr);
        } catch (_) {}
      }
    } catch (e) {
      developer.log('No wallet found or load failed: $e', name: 'locator');
    }
  }

  // Getters for services
  SharedPreferences get prefs => _prefs;
  InchClient get inchClient => _inchClient;
  MoralisClient get moralisClient => _moralisClient;
  ConfigService get configService => _configService;
  WalletService get walletService => _walletService;
  RpcClient get rpcClient => _rpcClient;
  TokenRegistry get tokenRegistry => _tokenRegistry;
  AnalyticsService get analyticsService => _analyticsService;
  NotificationService get notificationService => _notificationService;

  // Binance services (for charts and indicators)
  PollingService get pollingService => _pollingService;
  RankingService get rankingService => _rankingService;

  // 1inch adapters (for swap functionality)
  PricesAdapter get pricesAdapter => _pricesAdapter;
  PortfolioAdapter get portfolioAdapter => _portfolioAdapter;
  SwapAdapter get swapAdapter => _swapAdapter;

  /// Initialize for testing (similar to regular initialize but with minimal setup)
  Future<void> initializeForTesting() async {
    if (_isInitialized) return;

    // Initialize SharedPreferences  
    _prefs = await SharedPreferences.getInstance();

    // Initialize with minimal setup for testing
    _inchClient = InchClient();
    _moralisClient = MoralisClient();
    _configService = ConfigService();
    _walletService = WalletService();
    _rpcClient = RpcClient();

    // Initialize token registry with minimal data
    _tokenRegistry = TokenRegistry(
      inchClient: _inchClient,
      prefs: _prefs,
    );

    // Initialize Binance services
    _rankingService = RankingService();
    _pollingService = PollingService(rankingService: _rankingService);

    // Initialize 1inch adapters
    _pricesAdapter = PricesAdapter(
      inchClient: _inchClient,
      tokenRegistry: _tokenRegistry,
    );

    _portfolioAdapter = PortfolioAdapter(
      moralisClient: _moralisClient,
      walletService: _walletService,
      tokenRegistry: _tokenRegistry,
    );

    _swapAdapter = SwapAdapter(
      inchClient: _inchClient,
      walletService: _walletService,
      rpcClient: _rpcClient,
      tokenRegistry: _tokenRegistry,
      portfolioAdapter: _portfolioAdapter,
    );

    _isInitialized = true;
  }

  /// Clean shutdown
  void dispose() {
    _inchClient.dispose();
    _moralisClient.dispose();
    _rpcClient.dispose();
    _pollingService.stop();
    _rankingService.stop();
    _pricesAdapter.stop();
    _portfolioAdapter.dispose();
    _swapAdapter.dispose();
    _walletService.dispose();
  }
}

import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/inch_client.dart';
import '../services/moralis_client.dart';
import '../services/wert_service.dart';
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
  late WertService _wertService;
  late WalletService _walletService;
  late RpcClient _rpcClient;
  late TokenRegistry _tokenRegistry;
  
  // Binance services (for charts and indicators)
  late PollingService _pollingService;
  late RankingService _rankingService;
  
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
    _wertService = WertService();

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
  }

  /// Load wallet if exists and start portfolio sync
  Future<void> loadWalletIfExists() async {
    try {
      await _walletService.load();
      if (_walletService.isInitialized) {
        developer.log('Wallet loaded, syncing portfolio once', name: 'locator');
        // Sync once on wallet load, but don't start automatic periodic sync
        _portfolioAdapter.syncWithBlockchain();
      }
    } catch (e) {
      developer.log('No wallet found or load failed: $e', name: 'locator');
    }
  }

  // Getters for services
  SharedPreferences get prefs => _prefs;
  InchClient get inchClient => _inchClient;
  MoralisClient get moralisClient => _moralisClient;
  WertService get wertService => _wertService;
  WalletService get walletService => _walletService;
  RpcClient get rpcClient => _rpcClient;
  TokenRegistry get tokenRegistry => _tokenRegistry;

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

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/inch_client.dart';
import '../services/moralis_client.dart';
import '../onchain/wallet/wallet_service.dart';
import '../onchain/rpc/rpc_client.dart';
import '../data/token/token_registry.dart';
import '../data/prices/prices_adapter.dart';
import '../data/portfolio/portfolio_adapter.dart';
import '../onchain/swap/swap_adapter.dart';

/// Service locator for dependency injection
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Core dependencies
  late SharedPreferences _prefs;
  late InchClient _inchClient;
  late MoralisClient _moralisClient;
  late WalletService _walletService;
  late RpcClient _rpcClient;
  late TokenRegistry _tokenRegistry;
  
  // Adapters (replace old services)
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

    // Initialize blockchain services
    _walletService = WalletService();
    _rpcClient = RpcClient();

    // Initialize token registry
    _tokenRegistry = TokenRegistry(
      inchClient: _inchClient,
      prefs: _prefs,
    );
    await _tokenRegistry.initialize();

    // Initialize adapters (these replace the old services)
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
    print('🔍 SERVICE LOCATOR: All services initialized');
  }

  /// Load wallet if exists and start portfolio sync
  Future<void> loadWalletIfExists() async {
    try {
      await _walletService.load();
      if (_walletService.isInitialized) {
        print('🔍 SERVICE LOCATOR: Wallet loaded, syncing portfolio once');
        // Sync once on wallet load, but don't start automatic periodic sync
        _portfolioAdapter.syncWithBlockchain();
      }
    } catch (e) {
      print('🔍 SERVICE LOCATOR: No wallet found or load failed: $e');
    }
  }

  // Getters for services
  SharedPreferences get prefs => _prefs;
  InchClient get inchClient => _inchClient;
  MoralisClient get moralisClient => _moralisClient;
  WalletService get walletService => _walletService;
  RpcClient get rpcClient => _rpcClient;
  TokenRegistry get tokenRegistry => _tokenRegistry;

  // Adapters (these are what the UI will use)
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

    // Initialize adapters
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
    _pricesAdapter.stop();
    _portfolioAdapter.dispose();
    _swapAdapter.dispose();
    _walletService.dispose();
  }
}

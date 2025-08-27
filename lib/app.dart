import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/lifecycle.dart';
import 'core/service_locator.dart';
import 'features/portfolio/portfolio_screen.dart';
import 'features/swap/swap_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'storage/prefs_store.dart';

class CryptoSwapApp extends StatefulWidget {
  final PrefsStore prefsStore;
  final ServiceLocator serviceLocator;
  final AppLifecycleObserver lifecycleObserver;

  const CryptoSwapApp({
    super.key,
    required this.prefsStore,
    required this.serviceLocator,
    required this.lifecycleObserver,
  });

  @override
  State<CryptoSwapApp> createState() => _CryptoSwapAppState();
}

class _CryptoSwapAppState extends State<CryptoSwapApp> {
  int _selectedIndex = 0;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
    _selectedIndex = widget.prefsStore.getLastSelectedTab();
    
    // Debug: Check loaded portfolio
    final loadedPortfolio = widget.prefsStore.portfolio.value;
    print('🔍 DEBUG: Loaded portfolio from PrefsStore:');
    print('   USDT: ${loadedPortfolio.usdt}');
    print('   Positions: ${loadedPortfolio.positions}');
    
    // ⚠️ QUAN TRỌNG: Set portfolio in adapter TRƯỚC khi setup streams
    widget.serviceLocator.portfolioAdapter.setPortfolio(loadedPortfolio);
    
    // Debug: Check adapter state after setting
    print('🔍 DEBUG: Adapter portfolio after setPortfolio:');
    print('   USDT: ${widget.serviceLocator.portfolioAdapter.currentPortfolio.usdt}');
    print('   Positions: ${widget.serviceLocator.portfolioAdapter.currentPortfolio.positions}');
    
    // Setup streams SAU KHI đã set portfolio
    _setupPortfolioSync();
    
    // Start Binance services for charts and indicators
    // Pass TokenRegistry to RankingService to filter only BSC-compatible tokens
    widget.serviceLocator.rankingService.start(tokenRegistry: widget.serviceLocator.tokenRegistry);
    widget.serviceLocator.pollingService.start();
    
    // Start 1inch price adapter for swap functionality (optional, used for swap screen hardcoded tokens)
    // widget.serviceLocator.pricesAdapter.start();
  }

  void _checkWalletStatus() {
    // Check if wallet exists
    _needsOnboarding = !widget.serviceLocator.walletService.isInitialized;
    print('🔍 DEBUG: Needs onboarding: $_needsOnboarding');
  }

  void _setupPortfolioSync() {
    widget.serviceLocator.portfolioAdapter.portfolioStream.listen((portfolio) {
      widget.prefsStore.savePortfolio(portfolio);
    });

    widget.prefsStore.portfolio.addListener(() {
      widget.serviceLocator.portfolioAdapter.setPortfolio(widget.prefsStore.portfolio.value);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.prefsStore.setLastSelectedTab(index);
  }

  void _onOnboardingComplete() {
    setState(() {
      _needsOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.prefsStore.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'BSC Wallet',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: _needsOnboarding
              ? OnboardingFlow(
                  serviceLocator: widget.serviceLocator,
                  onComplete: _onOnboardingComplete,
                )
              : Scaffold(
                  body: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      PortfolioScreen(
                        prefsStore: widget.prefsStore,
                        pollingService: widget.serviceLocator.pollingService, // Use Binance for charts/indicators
                        portfolioEngine: widget.serviceLocator.portfolioAdapter, // Use portfolio adapter
                      ),
                      SwapScreen(
                        prefsStore: widget.prefsStore,
                        pollingService: widget.serviceLocator.pollingService, // Use Binance for price data
                        portfolioEngine: widget.serviceLocator.portfolioAdapter, // Use portfolio adapter
                      ),
                      SettingsScreen(
                        serviceLocator: widget.serviceLocator,
                      ),
                    ],
                  ),
                  bottomNavigationBar: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.account_balance_wallet),
                        label: 'Portfolio',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.swap_horiz),
                        label: 'Swap',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.settings),
                        label: 'Settings',
                      ),
                    ],
                    currentIndex: _selectedIndex,
                    onTap: _onItemTapped,
                  ),
                ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  @override
  void dispose() {
    widget.serviceLocator.dispose();
    super.dispose();
  }
}

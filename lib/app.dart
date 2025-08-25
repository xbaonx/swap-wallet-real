import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/lifecycle.dart';
import 'data/polling_service.dart';
import 'domain/logic/portfolio_engine.dart';
import 'features/portfolio/portfolio_screen.dart';
import 'features/swap/swap_screen.dart';
import 'storage/prefs_store.dart';

class CryptoSwapApp extends StatefulWidget {
  final PrefsStore prefsStore;
  final PollingService pollingService;
  final AppLifecycleObserver lifecycleObserver;

  const CryptoSwapApp({
    super.key,
    required this.prefsStore,
    required this.pollingService,
    required this.lifecycleObserver,
  });

  @override
  State<CryptoSwapApp> createState() => _CryptoSwapAppState();
}

class _CryptoSwapAppState extends State<CryptoSwapApp> {
  late final PortfolioEngine _portfolioEngine;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _portfolioEngine = PortfolioEngine();
    _selectedIndex = widget.prefsStore.getLastSelectedTab();
    
    // Debug: Check loaded portfolio
    final loadedPortfolio = widget.prefsStore.portfolio.value;
    print('🔍 DEBUG: Loaded portfolio from PrefsStore:');
    print('   USDT: ${loadedPortfolio.usdt}');
    print('   Positions: ${loadedPortfolio.positions}');
    
    // ⚠️ QUAN TRỌNG: Set portfolio TRƯỚC khi setup streams
    _portfolioEngine.setPortfolio(loadedPortfolio);
    
    // Debug: Check engine state after setting
    print('🔍 DEBUG: Engine portfolio after setPortfolio:');
    print('   USDT: ${_portfolioEngine.currentPortfolio.usdt}');
    print('   Positions: ${_portfolioEngine.currentPortfolio.positions}');
    
    // Setup streams SAU KHI đã set portfolio
    _setupPortfolioSync();
    
    widget.pollingService.start();
  }

  void _setupPortfolioSync() {
    _portfolioEngine.portfolioStream.listen((portfolio) {
      widget.prefsStore.savePortfolio(portfolio);
    });

    widget.prefsStore.portfolio.addListener(() {
      _portfolioEngine.setPortfolio(widget.prefsStore.portfolio.value);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.prefsStore.setLastSelectedTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.prefsStore.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Crypto Swap Simulator',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                PortfolioScreen(
                  prefsStore: widget.prefsStore,
                  pollingService: widget.pollingService,
                  portfolioEngine: _portfolioEngine,
                ),
                SwapScreen(
                  prefsStore: widget.prefsStore,
                  pollingService: widget.pollingService,
                  portfolioEngine: _portfolioEngine,
                ),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.swap_horiz),
                  label: 'Swap',
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
    _portfolioEngine.dispose();
    super.dispose();
  }
}

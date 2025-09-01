import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'core/i18n.dart';
import 'core/lifecycle.dart';
import 'core/service_locator.dart';
import 'core/storage.dart';
import 'core/lock_screen.dart';
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

class _CryptoSwapAppState extends State<CryptoSwapApp> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _needsOnboarding = true; // Default to true, will be updated in initState
  bool _wasBackground = false;
  bool _isLockShowing = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
    _selectedIndex = widget.prefsStore.getLastSelectedTab();
    WidgetsBinding.instance.addObserver(this);
    
    final loadedPortfolio = widget.prefsStore.portfolio.value;
    
    // Set portfolio in adapter before setting up streams
    widget.serviceLocator.portfolioAdapter.setPortfolio(loadedPortfolio);
    
    // Setup streams after portfolio is set
    _setupPortfolioSync();
    
    // Start Binance services for charts and indicators
    // Pass TokenRegistry to RankingService to filter only BSC-compatible tokens
    widget.serviceLocator.rankingService.start(tokenRegistry: widget.serviceLocator.tokenRegistry);
    widget.serviceLocator.pollingService.start();
    
    // Start 1inch price adapter for swap functionality (optional, used for swap screen hardcoded tokens)
    // widget.serviceLocator.pricesAdapter.start();

    // Yêu cầu khoá ngay khi khởi động nếu đã có thiết lập bảo mật (không áp dụng trong Onboarding)
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRequireInitialLock());
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    super.didChangeLocales(locales);
    // Nếu đang theo hệ thống, khi hệ thống đổi locale thì rebuild để cập nhật chuỗi AppI18n.trByCode(...)
    if (widget.prefsStore.language.value == 'system') {
      setState(() {});
    }
  }

  void _onSignOut() {
    developer.log('Sign out callback received → switching to onboarding', name: 'app');
    // Reset UI state and show onboarding again
    setState(() {
      _needsOnboarding = true;
      _selectedIndex = 0;
    });
    // Ensure no lock screen is being shown
    _isLockShowing = false;
  }

  void _checkWalletStatus() {
    // Check if wallet exists
    final needsOnboarding = !widget.serviceLocator.walletService.isInitialized;
    setState(() {
      _needsOnboarding = needsOnboarding;
    });
    developer.log('Wallet status checked: needsOnboarding=$_needsOnboarding', name: 'app');
  }

  void _setupPortfolioSync() {
    widget.serviceLocator.portfolioAdapter.portfolioStream.listen((portfolio) {
      widget.prefsStore.savePortfolio(portfolio);
      developer.log('Portfolio stream update saved to prefs', name: 'app');
    });

    widget.prefsStore.portfolio.addListener(() {
      widget.serviceLocator.portfolioAdapter.setPortfolio(widget.prefsStore.portfolio.value);
      developer.log('Prefs portfolio changed -> propagated to adapter', name: 'app');
    });
  }

  Future<void> _maybeRequireInitialLock() async {
    if (!mounted || _needsOnboarding) return;
    await _maybeRequireLock(reason: AppI18n.tr(context, 'auth.reason.continue'));
  }

  Future<void> _maybeRequireLock({required String reason}) async {
    if (!mounted || _isLockShowing) return;
    try {
      final hasPin = await SecureStorage.hasPinSet();
      final bio = await SecureStorage.isBiometricEnabled();
      if (!(hasPin || bio)) {
        return; // Không có cấu hình bảo mật → không khoá
      }
      if (!mounted) return;
      _isLockShowing = true;
      developer.log('Presenting LockScreen', name: 'app');
      final nav = _navigatorKey.currentState;
      if (nav != null) {
        await nav.push<bool>(
          MaterialPageRoute(
            builder: (_) => LockScreen(reason: reason),
            fullscreenDialog: true,
          ),
        );
      } else {
        developer.log('Navigator key not ready; skipping LockScreen', name: 'app');
      }
    } catch (e) {
      developer.log('Error showing LockScreen: $e', name: 'app');
    } finally {
      _isLockShowing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        developer.log('App resumed (wasBackground=$_wasBackground)', name: 'app');
        if (_wasBackground && !_needsOnboarding) {
          _wasBackground = false;
          _maybeRequireLock(reason: AppI18n.tr(context, 'auth.reason.continue'));
        }
        break;
      case AppLifecycleState.paused:
        developer.log('App paused → will require auth on resume', name: 'app');
        _wasBackground = true;
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.prefsStore.setLastSelectedTab(index);
  }

  void _onOnboardingComplete() async {
    // Reload wallet service to ensure fresh address
    try {
      developer.log('Onboarding complete callback: reloading wallet...', name: 'app');
      await widget.serviceLocator.walletService.load();
      developer.log('Wallet reloaded', name: 'app');
    } catch (e) {
      // Failed to reload wallet
      developer.log('Wallet reload failed after onboarding: $e', name: 'app');
    }
    
    setState(() {
      _needsOnboarding = false;
    });
    developer.log('Set _needsOnboarding=false and returning to main UI', name: 'app');
    
    // Auto-sync portfolio with blockchain after wallet creation
    try {
      developer.log('Triggering portfolio refresh after onboarding', name: 'app');
      await widget.serviceLocator.portfolioAdapter.refreshPortfolio();
      developer.log('Portfolio refresh completed', name: 'app');
    } catch (e) {
      // Portfolio auto-sync failed
      developer.log('Portfolio refresh failed after onboarding: $e', name: 'app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.prefsStore.themeMode,
      builder: (context, themeMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: widget.prefsStore.language,
          builder: (context, langCode, _) {
            return MaterialApp(
              title: AppI18n.trByCode(langCode, 'app.title'),
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              navigatorKey: _navigatorKey,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('vi')],
              locale: langCode == 'system' ? null : Locale(langCode),
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
                        prefsStore: widget.prefsStore,
                        onSignOut: _onSignOut,
                      ),
                    ],
                  ),
                  bottomNavigationBar: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.account_balance_wallet),
                        label: AppI18n.trByCode(langCode, 'nav.portfolio'),
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.swap_horiz),
                        label: AppI18n.trByCode(langCode, 'nav.swap'),
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.settings),
                        label: AppI18n.trByCode(langCode, 'nav.settings'),
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
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.serviceLocator.dispose();
    super.dispose();
  }
}

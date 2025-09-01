import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import '../../core/storage.dart';
import '../../core/i18n.dart';
import 'screens/welcome_screen.dart';
import 'screens/wallet_type_screen.dart';
import 'screens/create_wallet_screen.dart';
import 'screens/import_wallet_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/biometric_setup_screen.dart';
import 'screens/onboarding_complete_screen.dart';

class OnboardingFlow extends StatefulWidget {
  final ServiceLocator serviceLocator;
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.serviceLocator,
    required this.onComplete,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Onboarding state
  String? _generatedSeed;
  String? _importedSeed;
  bool _isImporting = false;
  String? _pin;
  bool _biometricEnabled = false;
  // Prevent duplicate completion
  bool _isCompleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 5) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onWalletTypeSelected(bool isImporting) {
    setState(() {
      _isImporting = isImporting;
    });
    _nextPage();
  }

  void _onSeedGenerated(String seed) {
    setState(() {
      _generatedSeed = seed;
    });
    _goToPage(3); // Skip confirm seed, go directly to PIN
  }

  void _onSeedImported(String seed) {
    setState(() {
      _importedSeed = seed;
    });
    _goToPage(3); // Go directly to PIN
  }

  // Removed _onSeedConfirmed - no longer needed

  void _onPinSet(String pin) {
    setState(() {
      _pin = pin;
    });
    _nextPage();
  }

  void _onBiometricSetup(bool enabled) {
    setState(() {
      _biometricEnabled = enabled;
    });
    _nextPage();
  }

  Future<void> _completeOnboarding() async {
    try {
      if (_isCompleting) {
        developer.log('Duplicate _completeOnboarding() call suppressed', name: 'onboarding');
        return;
      }
      _isCompleting = true;
      developer.log('Start complete flow | isImporting=$_isImporting', name: 'onboarding');
      // If creating a new wallet, derive from generated seed now.
      if (!_isImporting) {
        final seed = _generatedSeed;
        if (seed == null || seed.isEmpty) {
          throw Exception('Seed phrase is missing.');
        }
        developer.log('Creating wallet from generated seed...', name: 'onboarding');
        await widget.serviceLocator.walletService.createFromMnemonic(seed);
        developer.log('Wallet created in memory', name: 'onboarding');
      } else {
        // Import flow already initialized the wallet in ImportWalletScreen.
        developer.log('Import flow detected, wallet already initialized', name: 'onboarding');
      }

      // Persist the wallet for both create and import flows
      developer.log('Persisting wallet to secure storage...', name: 'onboarding');
      await widget.serviceLocator.walletService.persist();
      developer.log('Wallet persisted', name: 'onboarding');

      // Store mnemonic securely if available (do NOT log mnemonic content)
      try {
        final seedToStore = !_isImporting ? _generatedSeed : _importedSeed;
        if (seedToStore != null && seedToStore.isNotEmpty) {
          developer.log('Storing mnemonic securely (content hidden)', name: 'onboarding');
          await SecureStorage.storeMnemonic(seedToStore);
        } else {
          developer.log('No mnemonic to store (imported via private key or missing)', name: 'onboarding');
        }
      } catch (e) {
        // Non-fatal: mnemonic storage failure should not block onboarding, but notify user lightly
        developer.log('Failed to store mnemonic securely: $e', name: 'onboarding');
      }
      
      // Clear in-memory sensitive data ASAP
      _generatedSeed = null;
      _importedSeed = null;
      // Trigger a one-time portfolio sync after wallet is ready (defer to next frame)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          developer.log('Trigger portfolio sync', name: 'onboarding');
          widget.serviceLocator.portfolioAdapter.syncWithBlockchain();
          developer.log('Portfolio sync triggered', name: 'onboarding');
        } catch (_) {
          // Non-fatal: ignore portfolio sync errors here
          developer.log('Portfolio sync threw non-fatal error', name: 'onboarding');
        }
      });

      // Store PIN if provided (non-empty)
      if (_pin != null && _pin!.isNotEmpty) {
        developer.log('Storing PIN hash', name: 'onboarding');
        await SecureStorage.storePinHash(_pin!);
      }
      
      // Clear in-memory PIN as soon as it has been persisted
      _pin = null;
      // Store biometric preference
      developer.log('Setting biometric enabled = $_biometricEnabled', name: 'onboarding');
      await SecureStorage.setBiometricEnabled(_biometricEnabled);

      // Call completion callback to return to main app
      developer.log('Calling onComplete callback', name: 'onboarding');
      widget.onComplete();
      developer.log('Complete flow done', name: 'onboarding');
    } catch (e) {
      developer.log('FAILED -> $e', name: 'onboarding');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppI18n.tr(context, 'onboarding.flow.error.failed')}: $e')),
        );
      } else {
        developer.log('Unable to show SnackBar because widget is not mounted', name: 'onboarding');
      }
      rethrow;
    } finally {
      _isCompleting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 0: Welcome
          WelcomeScreen(
            onNext: _nextPage,
          ),
          
          // 1: Wallet Type Selection
          WalletTypeScreen(
            onWalletTypeSelected: _onWalletTypeSelected,
            onBack: _previousPage,
          ),
          
          // 2: Create Wallet (seed generation)
          if (!_isImporting)
            CreateWalletScreen(
              serviceLocator: widget.serviceLocator,
              onSeedGenerated: _onSeedGenerated,
              onBack: _previousPage,
            )
          else
            // 2: Import Wallet (seed input)
            ImportWalletScreen(
              serviceLocator: widget.serviceLocator,
              onSeedImported: _onSeedImported,
              onBack: _previousPage,
            ),
          
          // 3: PIN Setup
          PinSetupScreen(
            onPinSet: _onPinSet,
            onSkip: () => _onPinSet(''), // Empty PIN = skip
            onBack: _previousPage,
            title: AppI18n.tr(context, 'onboarding.pin.appbar'),
          ),
          
          // 4: Biometric Setup
          BiometricSetupScreen(
            onBiometricSetup: _onBiometricSetup,
            onBack: _previousPage,
          ),
          
          // 5: Complete
          OnboardingCompleteScreen(
            isImporting: _isImporting,
            onComplete: _completeOnboarding,
          ),
        ],
      ),
    );
  }
}

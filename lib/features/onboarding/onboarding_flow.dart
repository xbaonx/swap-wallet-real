import 'package:flutter/material.dart';
import '../../core/service_locator.dart';
import 'screens/welcome_screen.dart';
import 'screens/wallet_type_screen.dart';
import 'screens/create_wallet_screen.dart';
import 'screens/import_wallet_screen.dart';
import 'screens/confirm_seed_screen.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 7) {
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
    _nextPage();
  }

  void _onSeedImported(String seed) {
    setState(() {
      _importedSeed = seed;
    });
    _goToPage(4); // Skip confirm seed for imports, go to PIN
  }

  void _onSeedConfirmed() {
    _nextPage();
  }

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
      final seed = _isImporting ? _importedSeed! : _generatedSeed!;
      
      // Create wallet from seed
      await widget.serviceLocator.walletService.createFromMnemonic(seed);
      
      // Persist the wallet
      await widget.serviceLocator.walletService.persist();
      
      // Set PIN if provided
      if (_pin != null) {
        // TODO: Store PIN securely
      }
      
      // Set biometric preference
      if (_biometricEnabled) {
        // TODO: Enable biometric authentication
      }
      
      // Call completion callback to return to main app
      widget.onComplete();
    } catch (e) {
      print('Error completing onboarding: $e');
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
          
          // 3: Confirm Seed (only for new wallets)
          if (!_isImporting && _generatedSeed != null)
            ConfirmSeedScreen(
              seedPhrase: _generatedSeed!,
              onSeedConfirmed: _onSeedConfirmed,
              onBack: _previousPage,
            )
          else
            Container(), // Placeholder for imports
          
          // 4: PIN Setup
          PinSetupScreen(
            onPinSet: _onPinSet,
            onSkip: () => _onPinSet(''), // Empty PIN = skip
            onBack: _previousPage,
          ),
          
          // 5: Biometric Setup
          BiometricSetupScreen(
            onBiometricSetup: _onBiometricSetup,
            onBack: _previousPage,
          ),
          
          // 6: Complete
          OnboardingCompleteScreen(
            isImporting: _isImporting,
            onComplete: _completeOnboarding,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/service_locator.dart';
import '../../../core/i18n.dart';

class ImportWalletScreen extends StatefulWidget {
  final ServiceLocator serviceLocator;
  final Function(String seed) onSeedImported;
  final VoidCallback onBack;

  const ImportWalletScreen({
    super.key,
    required this.serviceLocator,
    required this.onSeedImported,
    required this.onBack,
  });

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  bool _isSeedImport = true;
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _seedController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _switchImportType(bool isSeed) {
    setState(() {
      _isSeedImport = isSeed;
      _errorMessage = null;
    });
  }

  Future<void> _importWallet() async {
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      String seed;
      
      if (_isSeedImport) {
        // Import from seed phrase
        final seedText = _seedController.text.trim().toLowerCase();
        if (seedText.isEmpty) {
          throw Exception(AppI18n.tr(context, 'onboarding.import.error.enter_seed'));
        }
        
        final words = seedText.split(RegExp(r'\s+'));
        if (words.length != 12 && words.length != 24) {
          throw Exception(AppI18n.tr(context, 'onboarding.import.error.seed_12_24'));
        }
        
        // Validate seed phrase format
        if (!widget.serviceLocator.walletService.validateMnemonic(seedText)) {
          throw Exception(AppI18n.tr(context, 'onboarding.import.error.invalid_seed'));
        }
        
        // ACTUALLY IMPORT the wallet from mnemonic
        await widget.serviceLocator.walletService.importFromMnemonic(seedText);
        
        seed = seedText;
      } else {
        // Import from private key
        final privateKey = _privateKeyController.text.trim();
        if (privateKey.isEmpty) {
          throw Exception(AppI18n.tr(context, 'onboarding.import.error.enter_pk'));
        }
        
        // Validate private key format (64 hex chars, with or without 0x prefix)
        String cleanKey = privateKey.toLowerCase();
        if (cleanKey.startsWith('0x')) {
          cleanKey = cleanKey.substring(2);
        }
        
        if (cleanKey.length != 64 || !RegExp(r'^[0-9a-f]+$').hasMatch(cleanKey)) {
          throw Exception(AppI18n.tr(context, 'onboarding.import.error.invalid_pk'));
        }
        
        // ACTUALLY IMPORT the wallet from private key
        await widget.serviceLocator.walletService.importFromPrivateKey('0x$cleanKey');
        
        // Do not fabricate a mnemonic for private key imports
        seed = '';
      }

      widget.onSeedImported(seed);
    } catch (e) {
      setState(() {
        final msg = e.toString();
        _errorMessage = msg.startsWith('Exception: ') ? msg.substring('Exception: '.length) : msg;
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text(AppI18n.tr(context, 'onboarding.import.appbar')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
              
                Text(
                  AppI18n.tr(context, 'onboarding.import.title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              
                const SizedBox(height: 16),
              
                Text(
                  AppI18n.tr(context, 'onboarding.import.subtitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              
                const SizedBox(height: 32),
              
                // Import Type Toggle
                Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchImportType(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isSeedImport ? Colors.blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppI18n.tr(context, 'onboarding.import.toggle.seed'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isSeedImport ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchImportType(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isSeedImport ? Colors.blue : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppI18n.tr(context, 'onboarding.import.toggle.private'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !_isSeedImport ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              
                const SizedBox(height: 32),
              
                // Input Field
                if (_isSeedImport) ...[
                  TextField(
                    controller: _seedController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: AppI18n.tr(context, 'onboarding.import.input.seed.label'),
                      hintText: AppI18n.tr(context, 'onboarding.import.input.seed.hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _errorMessage,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _importWallet(),
                  ),
                ] else ...[
                  TextField(
                    controller: _privateKeyController,
                    decoration: InputDecoration(
                      labelText: AppI18n.tr(context, 'onboarding.import.input.private.label'),
                      hintText: AppI18n.tr(context, 'onboarding.import.input.private.hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _errorMessage,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _importWallet(),
                    obscureText: true,
                  ),
                ],
              
                const SizedBox(height: 32),
              
                // Security Warning
                Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.amber[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppI18n.tr(context, 'onboarding.import.security.title'),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppI18n.tr(context, 'onboarding.import.security.desc'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              
                const SizedBox(height: 32),
              
                // Import Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _importWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isValidating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            AppI18n.tr(context, 'onboarding.import.button'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

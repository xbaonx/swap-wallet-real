import 'package:flutter/material.dart';
import '../../../core/service_locator.dart';

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
          throw Exception('Please enter your seed phrase');
        }
        
        final words = seedText.split(RegExp(r'\s+'));
        if (words.length != 12 && words.length != 24) {
          throw Exception('Seed phrase must be 12 or 24 words');
        }
        
        // Validate seed phrase format
        if (!widget.serviceLocator.walletService.validateMnemonic(seedText)) {
          throw Exception('Invalid seed phrase');
        }
        
        seed = seedText;
      } else {
        // Import from private key
        final privateKey = _privateKeyController.text.trim();
        if (privateKey.isEmpty) {
          throw Exception('Please enter your private key');
        }
        
        // Validate private key format (64 hex chars, with or without 0x prefix)
        String cleanKey = privateKey.toLowerCase();
        if (cleanKey.startsWith('0x')) {
          cleanKey = cleanKey.substring(2);
        }
        
        if (cleanKey.length != 64 || !RegExp(r'^[0-9a-f]+$').hasMatch(cleanKey)) {
          throw Exception('Invalid private key format');
        }
        
        // Generate seed from private key for storage consistency
        seed = await widget.serviceLocator.walletService.generateMnemonic();
      }

      widget.onSeedImported(seed);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
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
        title: const Text('Import Wallet'),
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
                'Restore Your Wallet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Enter your seed phrase or private key to restore your existing wallet',
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
                            'Seed Phrase',
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
                            'Private Key',
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
                    labelText: 'Seed Phrase',
                    hintText: 'Enter your 12 or 24 word seed phrase',
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
                    labelText: 'Private Key',
                    hintText: 'Enter your private key (with or without 0x prefix)',
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
                            'Security Notice',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Make sure you\'re in a secure environment. Your seed phrase or private key gives full access to your wallet.',
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
                      : const Text(
                          'Import Wallet',
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
    );
  }
}

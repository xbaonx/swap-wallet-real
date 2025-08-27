import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/service_locator.dart';

class CreateWalletScreen extends StatefulWidget {
  final ServiceLocator serviceLocator;
  final Function(String seed) onSeedGenerated;
  final VoidCallback onBack;

  const CreateWalletScreen({
    super.key,
    required this.serviceLocator,
    required this.onSeedGenerated,
    required this.onBack,
  });

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  String? _generatedSeed;
  bool _isRevealed = false;
  bool _isCopied = false;
  bool _hasConfirmedBackup = false;

  @override
  void initState() {
    super.initState();
    _generateSeed();
  }

  void _generateSeed() async {
    try {
      final seed = await widget.serviceLocator.walletService.generateMnemonic();
      setState(() {
        _generatedSeed = seed;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating seed: $e')),
      );
    }
  }

  void _revealSeed() {
    setState(() {
      _isRevealed = true;
    });
  }

  void _copySeed() {
    if (_generatedSeed != null) {
      Clipboard.setData(ClipboardData(text: _generatedSeed!));
      setState(() {
        _isCopied = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seed phrase copied to clipboard')),
      );
    }
  }

  void _continue() {
    if (_generatedSeed != null && _hasConfirmedBackup) {
      widget.onSeedGenerated(_generatedSeed!);
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
        title: const Text('Create Wallet'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              
              Text(
                'Backup Your Wallet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Write down or copy these 12 words in the exact order shown. This is your recovery phrase.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Seed Phrase Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    if (!_isRevealed) ...[
                      const Icon(
                        Icons.visibility_off,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to reveal your seed phrase',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _revealSeed,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Reveal Seed Phrase'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else ...[
                      _buildSeedPhraseGrid(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copySeed,
                              icon: Icon(_isCopied ? Icons.check : Icons.copy),
                              label: Text(_isCopied ? 'Copied!' : 'Copy'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _generateSeed,
                              icon: const Icon(Icons.refresh),
                              label: const Text('New Phrase'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Security Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Security Notice',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Never share your seed phrase with anyone. Store it safely offline. Anyone with this phrase can access your wallet.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Confirmation Checkbox
              if (_isRevealed) ...[
                CheckboxListTile(
                  value: _hasConfirmedBackup,
                  onChanged: (value) {
                    setState(() {
                      _hasConfirmedBackup = value ?? false;
                    });
                  },
                  title: Text(
                    'I have safely backed up my seed phrase',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                
                const SizedBox(height: 16),
              ],
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isRevealed && _hasConfirmedBackup) ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
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

  Widget _buildSeedPhraseGrid() {
    if (_generatedSeed == null) return Container();
    
    final words = _generatedSeed!.split(' ');
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
              Text(
                words[index],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

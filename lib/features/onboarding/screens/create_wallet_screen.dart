import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;
import '../../../core/service_locator.dart';
import '../../../core/i18n.dart';

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
    // Precompute UI dependencies before async gap
    final messenger = ScaffoldMessenger.of(context);
    final i18nErrorPrefix = AppI18n.tr(context, 'onboarding.create.error.seed_generate');
    try {
      final seed = await widget.serviceLocator.walletService.generateMnemonic();
      if (!mounted) return;
      setState(() {
        _generatedSeed = seed;
      });
      // Debug-only: log seed metadata (do NOT log actual words)
      final wc = seed.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      dev.log('Seed generated: $wc words', name: 'onboarding.ui');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$i18nErrorPrefix: $e')),
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
        SnackBar(content: Text(AppI18n.tr(context, 'onboarding.create.copied_snackbar'))),
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
        title: Text(AppI18n.tr(context, 'onboarding.create.appbar')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          AppI18n.tr(context, 'onboarding.create.title'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppI18n.tr(context, 'onboarding.create.subtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 32),
                        // Seed Phrase Display
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            children: [
                              if (!_isRevealed) ...[
                                Icon(
                                  Icons.visibility_off,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppI18n.tr(context, 'onboarding.create.tap_to_reveal'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _revealSeed,
                                  icon: const Icon(Icons.visibility),
                                  label: Text(AppI18n.tr(context, 'onboarding.create.reveal_button')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ] else ...[
                                if (_generatedSeed == null) ...[
                                  const SizedBox(height: 8),
                                  const Center(child: CircularProgressIndicator()),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppI18n.tr(context, 'onboarding.create.generating'),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ] else ...[
                                  _buildSeedSection(),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _copySeed,
                                          icon: Icon(_isCopied ? Icons.check : Icons.copy),
                                          label: Text(_isCopied ? AppI18n.tr(context, 'onboarding.create.copied') : AppI18n.tr(context, 'onboarding.create.copy')),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _generateSeed,
                                          icon: const Icon(Icons.refresh),
                                          label: Text(AppI18n.tr(context, 'onboarding.create.new_phrase')),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Security Warning
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
                                      AppI18n.tr(context, 'onboarding.create.security.title'),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red[700],
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppI18n.tr(context, 'onboarding.create.security.desc'),
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
                      ],
                    ),
                    // Bottom area
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isRevealed) ...[
                          CheckboxListTile(
                            value: _hasConfirmedBackup,
                            onChanged: (value) {
                              setState(() {
                                _hasConfirmedBackup = value ?? false;
                              });
                            },
                            title: Text(
                              AppI18n.tr(context, 'onboarding.create.checkbox'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_isRevealed && _hasConfirmedBackup) ? _continue : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              AppI18n.tr(context, 'onboarding.create.continue'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeedPhraseGrid() {
    if (_generatedSeed == null) return Container();
    
    final words = _generatedSeed!
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    // Fixed 3 columns for tidy layout (very small screens still fall back to list)
    const tileAspect = 1.5; // width / height (taller tiles for readability)

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: tileAspect,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  words[index],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildNumberedSeedLine() {
    if (_generatedSeed == null) return '';
    final words = _generatedSeed!
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final numbered = List.generate(words.length, (i) => '${i + 1}. ${words[i]}');
    return numbered.join('   ');
  }

  Widget _buildSeedSection() {
    final width = MediaQuery.of(context).size.width;
    // On very small screens, show a vertical list to guarantee readability
    if (width < 340) {
      return _buildSeedList();
    }

    return Column(
      children: [
        _buildSeedPhraseGrid(),
        const SizedBox(height: 8),
        // Additionally show a selectable one-line fallback
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: SelectableText(
            _buildNumberedSeedLine(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeedList() {
    final words = _generatedSeed!
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Text(
                '${index + 1}'.padLeft(2, '0'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  words[index],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class ConfirmSeedScreen extends StatefulWidget {
  final String seedPhrase;
  final VoidCallback onSeedConfirmed;
  final VoidCallback onBack;

  const ConfirmSeedScreen({
    super.key,
    required this.seedPhrase,
    required this.onSeedConfirmed,
    required this.onBack,
  });

  @override
  State<ConfirmSeedScreen> createState() => _ConfirmSeedScreenState();
}

class _ConfirmSeedScreenState extends State<ConfirmSeedScreen> {
  List<String> _seedWords = [];
  List<String> _shuffledWords = [];
  List<String> _selectedWords = [];
  List<int> _testIndices = [];

  @override
  void initState() {
    super.initState();
    _setupConfirmation();
  }

  void _setupConfirmation() {
    _seedWords = widget.seedPhrase.split(' ');
    
    // Select 6 random positions to test
    final allIndices = List.generate(12, (index) => index);
    allIndices.shuffle();
    _testIndices = allIndices.take(6).toList()..sort();
    
    // Create shuffled list of words for the test positions
    _shuffledWords = _testIndices.map((index) => _seedWords[index]).toList();
    _shuffledWords.shuffle();
    
    // Initialize selected words
    _selectedWords = List.filled(_testIndices.length, '');
  }

  void _selectWord(String word, int targetIndex) {
    setState(() {
      // Clear any existing instance of this word
      for (int i = 0; i < _selectedWords.length; i++) {
        if (_selectedWords[i] == word) {
          _selectedWords[i] = '';
        }
      }
      // Set the word at target index
      _selectedWords[targetIndex] = word;
    });
  }

  void _clearWord(int index) {
    setState(() {
      _selectedWords[index] = '';
    });
  }

  bool _isComplete() {
    return _selectedWords.every((word) => word.isNotEmpty);
  }

  bool _isCorrect() {
    for (int i = 0; i < _testIndices.length; i++) {
      final expectedWord = _seedWords[_testIndices[i]];
      if (_selectedWords[i] != expectedWord) {
        return false;
      }
    }
    return true;
  }

  void _verify() {
    if (_isComplete()) {
      if (_isCorrect()) {
        widget.onSeedConfirmed();
      } else {
        _showErrorDialog();
      }
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Incorrect Seed Phrase'),
        content: const Text('The words you selected don\'t match your seed phrase. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setupConfirmation();
              setState(() {});
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Confirm Seed Phrase'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 16),
              
              Text(
                'Confirm Your\nSeed Phrase',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Please select the correct words to confirm you\'ve backed up your seed phrase',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Test positions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'Select the missing words:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTestPositions(),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Word options
              Text(
                'Available words:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildWordOptions(),
              
              const Spacer(),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isComplete() ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Verify',
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

  Widget _buildTestPositions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _testIndices.asMap().entries.map((entry) {
        final index = entry.key;
        final position = entry.value + 1;
        final selectedWord = _selectedWords[index];
        
        return GestureDetector(
          onTap: selectedWord.isNotEmpty ? () => _clearWord(index) : null,
          child: Container(
            width: 100,
            height: 48,
            decoration: BoxDecoration(
              color: selectedWord.isNotEmpty
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedWord.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                width: selectedWord.isNotEmpty ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$position',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedWord.isNotEmpty ? selectedWord : '___',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selectedWord.isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWordOptions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _shuffledWords.map((word) {
        final isSelected = _selectedWords.contains(word);
        
        return GestureDetector(
          onTap: isSelected ? null : () {
            final nextEmptyIndex = _selectedWords.indexWhere((w) => w.isEmpty);
            if (nextEmptyIndex != -1) {
              _selectWord(word, nextEmptyIndex);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.surfaceVariant
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).dividerColor
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            child: Text(
              word,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/i18n.dart';

class PinSetupScreen extends StatefulWidget {
  final Function(String pin) onPinSet;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final bool showSkip;
  final String title;

  const PinSetupScreen({
    super.key,
    required this.onPinSet,
    required this.onSkip,
    required this.onBack,
    this.showSkip = true,
    this.title = 'Setup PIN',
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirmMode = false;
  String? _errorMessage;

  void _onNumberPressed(String number) {
    setState(() {
      _errorMessage = null;
      
      if (!_isConfirmMode) {
        if (_enteredPin.length < 6) {
          _enteredPin += number;
          if (_enteredPin.length == 6) {
            _isConfirmMode = true;
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += number;
          if (_confirmPin.length == 6) {
            _validatePins();
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      _errorMessage = null;
      
      if (!_isConfirmMode) {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  void _validatePins() {
    if (_enteredPin == _confirmPin) {
      widget.onPinSet(_enteredPin);
    } else {
      setState(() {
        _errorMessage = AppI18n.tr(context, 'onboarding.pin.error.mismatch');
        _enteredPin = '';
        _confirmPin = '';
        _isConfirmMode = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _enteredPin = '';
      _confirmPin = '';
      _isConfirmMode = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          if (widget.showSkip)
            TextButton(
              onPressed: widget.onSkip,
              child: Text(AppI18n.tr(context, 'onboarding.pin.skip')),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48, // account for vertical padding
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Icon(
                        Icons.lock,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isConfirmMode
                            ? AppI18n.tr(context, 'onboarding.pin.title.confirm')
                            : AppI18n.tr(context, 'onboarding.pin.title.create'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isConfirmMode
                            ? AppI18n.tr(context, 'onboarding.pin.subtitle.confirm')
                            : AppI18n.tr(context, 'onboarding.pin.subtitle.create'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 32),
                      // PIN Display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final currentPin = _isConfirmMode ? _confirmPin : _enteredPin;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < currentPin.length
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      // Error Message
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _reset,
                          child: Text(AppI18n.tr(context, 'onboarding.pin.try_again')),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Number Pad
                      _buildNumberPad(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        // Numbers 1-3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ],
        ),
        const SizedBox(height: 16),
        
        // Numbers 4-6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ],
        ),
        const SizedBox(height: 16),
        
        // Numbers 7-9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ],
        ),
        const SizedBox(height: 16),
        
        // 0 and Delete
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72), // Empty space
            _buildNumberButton('0'),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Text(
            number,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: Icon(
            Icons.backspace,
            size: 24,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

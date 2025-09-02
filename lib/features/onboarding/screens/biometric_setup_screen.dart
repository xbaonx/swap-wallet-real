import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/i18n.dart';

class BiometricSetupScreen extends StatefulWidget {
  final Function(bool enabled) onBiometricSetup;
  final VoidCallback onBack;

  const BiometricSetupScreen({
    super.key,
    required this.onBiometricSetup,
    required this.onBack,
  });

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  bool _isChecking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final types = await _auth.getAvailableBiometrics();
      final available = supported && canCheck && types.isNotEmpty;
      if (!mounted) return;
      setState(() {
        _isBiometricAvailable = available;
        _isChecking = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBiometricAvailable = false;
        _isChecking = false;
        _error = e.toString();
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
        title: Text(AppI18n.tr(context, 'onboarding.biometric.appbar')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              
              // Biometric Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                AppI18n.tr(context, 'onboarding.biometric.title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                AppI18n.tr(context, 'onboarding.biometric.subtitle'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Benefits
              _buildBenefit(
                Icons.speed,
                AppI18n.tr(context, 'onboarding.biometric.benefit.quick.title'),
                AppI18n.tr(context, 'onboarding.biometric.benefit.quick.desc'),
              ),
              
              const SizedBox(height: 20),
              
              _buildBenefit(
                Icons.security,
                AppI18n.tr(context, 'onboarding.biometric.benefit.security.title'),
                AppI18n.tr(context, 'onboarding.biometric.benefit.security.desc'),
              ),
              
              const SizedBox(height: 20),
              
              _buildBenefit(
                Icons.privacy_tip,
                AppI18n.tr(context, 'onboarding.biometric.benefit.privacy.title'),
                AppI18n.tr(context, 'onboarding.biometric.benefit.privacy.desc'),
              ),
              
              const Spacer(),
              if (_isChecking) ...[
                const SizedBox(height: 8),
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(height: 24),
              ],
              
              if (!_isBiometricAvailable && !_isChecking) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: Colors.orange[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error == null
                              ? AppI18n.tr(context, 'onboarding.biometric.not_available')
                              : '${AppI18n.tr(context, 'onboarding.biometric.check_failed')}: \n$_error',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Enable Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (!_isChecking && _isBiometricAvailable) 
                      ? () => widget.onBiometricSetup(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fingerprint),
                      const SizedBox(width: 8),
                      Text(
                        AppI18n.tr(context, 'onboarding.biometric.enable_button'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Skip Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: () => widget.onBiometricSetup(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    AppI18n.tr(context, 'onboarding.biometric.skip'),
                    style: const TextStyle(
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

  Widget _buildBenefit(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.green,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

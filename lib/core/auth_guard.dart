import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:developer' as dev;

import 'storage.dart';
import '../features/onboarding/screens/pin_verify_screen.dart';

class AuthGuard {
  const AuthGuard._();

  static Future<bool> requireAuth(
    BuildContext context, {
    required String reason,
  }) async {
    try {
      // 1) Biometric first if enabled
      final biometricEnabled = await SecureStorage.isBiometricEnabled();
      if (biometricEnabled) {
        try {
          final available = await isBiometricAvailable();
          if (available) {
            final ok = await authenticateBiometricOnly(reason: reason);
            if (ok) return true;
          }
        } catch (e) {
          // Fall through to PIN
          dev.log('Biometric auth error: $e', name: 'auth');
        }
      }

      // 2) Fallback to PIN if configured
      final hasPin = await SecureStorage.hasPinSet();
      if (!hasPin) {
        if (context.mounted) {
          await _showSecurityNotConfiguredDialog(context);
        }
        return false;
      }

      if (!context.mounted) return false;
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (ctx) => PinVerifyScreen(
            title: 'Nhập PIN',
            description: 'Nhập PIN để tiếp tục',
            onBack: () => Navigator.pop(ctx, false),
            onVerified: () => Navigator.pop(ctx, true),
          ),
        ),
      );
      return verified == true;
    } catch (e) {
      dev.log('AuthGuard.requireAuth error: $e', name: 'auth');
      return false;
    }
  }

  // Check whether biometric is available and enrolled on device
  static Future<bool> isBiometricAvailable() async {
    try {
      final localAuth = LocalAuthentication();
      final supported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      final types = await localAuth.getAvailableBiometrics();
      return supported && canCheck && types.isNotEmpty;
    } catch (e) {
      dev.log('Biometric availability check error: $e', name: 'auth');
      return false;
    }
  }

  // Prompt biometric once (biometric only). Returns true if user authenticated successfully.
  static Future<bool> authenticateBiometricOnly({
    required String reason,
  }) async {
    try {
      final localAuth = LocalAuthentication();
      final ok = await localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok;
    } catch (e) {
      dev.log('Biometric authenticate error: $e', name: 'auth');
      return false;
    }
  }

  static Future<void> _showSecurityNotConfiguredDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bảo mật chưa được thiết lập'),
        content: const Text('Bạn cần bật xác thực sinh trắc học hoặc đặt PIN trong phần Security để tiếp tục.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

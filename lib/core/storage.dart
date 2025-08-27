import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'errors.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Secure storage keys
  static const String _walletKey = 'WALLET_V1';
  static const String _pinHashKey = 'PIN_HASH';
  static const String _biometricEnabledKey = 'BIOMETRIC_ENABLED';

  /// Store encrypted wallet data
  static Future<void> storeWallet(String encryptedData) async {
    try {
      await _storage.write(key: _walletKey, value: encryptedData);
    } catch (e) {
      throw AppError.unknown('Failed to store wallet: $e');
    }
  }

  /// Retrieve encrypted wallet data
  static Future<String?> getWallet() async {
    try {
      return await _storage.read(key: _walletKey);
    } catch (e) {
      throw AppError.unknown('Failed to retrieve wallet: $e');
    }
  }

  /// Check if wallet exists
  static Future<bool> hasWallet() async {
    final data = await getWallet();
    return data != null && data.isNotEmpty;
  }

  /// Delete wallet data (for reset/logout)
  static Future<void> deleteWallet() async {
    try {
      await _storage.delete(key: _walletKey);
      await _storage.delete(key: _pinHashKey);
      await _storage.delete(key: _biometricEnabledKey);
    } catch (e) {
      throw AppError.unknown('Failed to delete wallet: $e');
    }
  }

  /// Store PIN hash
  static Future<void> storePinHash(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  /// Verify PIN
  static Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) return false;
    
    final inputHash = _hashPin(pin);
    return storedHash == inputHash;
  }

  /// Check if PIN is set
  static Future<bool> hasPinSet() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Enable/disable biometric authentication
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  /// Check if biometric is enabled
  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  static String _hashPin(String pin) {
    // Use SHA-256 with salt for PIN hashing
    final salt = 'BSC_WALLET_PIN_SALT_V1';
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clear all secure storage (for debugging/reset)
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw AppError.unknown('Failed to clear storage: $e');
    }
  }
}

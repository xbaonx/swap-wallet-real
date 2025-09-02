import 'dart:developer' as dev;
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/http.dart';

class NotificationService {
  final HttpClient _httpClient;
  final SharedPreferences _prefs;
  final String _backendBase;

  NotificationService({
    required SharedPreferences prefs,
  })  : _prefs = prefs,
        _backendBase = dotenv.env['BACKEND_BASE_URL'] ?? '',
        _httpClient = HttpClient(
          defaultHeaders: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

  bool get isEnabled => _backendBase.isNotEmpty;

  String _detectPlatform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }

  /// Register device for notifications
  /// - walletAddress: EIP-55, required by backend (0x... 42 chars)
  /// - externalUserId: default to walletAddress for stable alias mapping
  /// - platform: auto-detected if not provided
  Future<bool> registerDevice({
    required String walletAddress,
    String? externalUserId,
    String? platform,
  }) async {
    if (!isEnabled) {
      dev.log('Notifications disabled: missing BACKEND_BASE_URL', name: 'notify');
      return false;
    }
    try {
      final url = '$_backendBase/api/notify/register';
      final payload = {
        'wallet_address': walletAddress,
        'external_user_id': (externalUserId == null || externalUserId.isEmpty)
            ? walletAddress
            : externalUserId,
        'platform': platform ?? _detectPlatform(),
      };
      final resp = await _httpClient.post(url, data: payload);
      final ok = (resp.statusCode ?? 0) >= 200 && (resp.statusCode ?? 0) < 300;
      if (!ok) {
        dev.log('Notify register failed HTTP ${resp.statusCode}: ${resp.data}', name: 'notify');
      }
      return ok;
    } catch (e) {
      dev.log('Notify register error: $e', name: 'notify');
      return false;
    }
  }
}

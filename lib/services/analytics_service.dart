import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/http.dart';

class AnalyticsService {
  static const _prefsKeySessionId = 'analytics.session_id';

  final HttpClient _httpClient;
  final SharedPreferences _prefs;
  final String _backendBase;

  String? _cachedSessionId;

  AnalyticsService({
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

  Future<String> getOrCreateSessionId() async {
    if (_cachedSessionId != null) return _cachedSessionId!;
    final existed = _prefs.getString(_prefsKeySessionId);
    if (existed != null && existed.isNotEmpty) {
      _cachedSessionId = existed;
      return existed;
    }
    final sid = _generatePseudoUuidV4();
    await _prefs.setString(_prefsKeySessionId, sid);
    _cachedSessionId = sid;
    return sid;
  }

  Future<bool> track({
    required String eventName,
    Map<String, dynamic>? props,
    String? walletAddress,
  }) async {
    if (!isEnabled) {
      dev.log('Analytics disabled: missing BACKEND_BASE_URL', name: 'analytics');
      return false;
    }
    try {
      final sessionId = await getOrCreateSessionId();
      final url = '$_backendBase/api/analytics/track';
      final payload = {
        'event_name': eventName,
        'session_id': sessionId,
        if (walletAddress != null && walletAddress.isNotEmpty) 'wallet_address': walletAddress,
        if (props != null) 'props': props,
      };
      final resp = await _httpClient.post(url, data: payload);
      final ok = (resp.statusCode ?? 0) >= 200 && (resp.statusCode ?? 0) < 300;
      if (!ok) {
        dev.log('Track failed HTTP ${resp.statusCode}: ${resp.data}', name: 'analytics');
      }
      return ok;
    } catch (e) {
      dev.log('Track error: $e', name: 'analytics');
      return false;
    }
  }

  String _generatePseudoUuidV4() {
    final rnd = Random.secure();
    String block(int len) {
      const hex = '0123456789abcdef';
      return List.generate(len, (_) => hex[rnd.nextInt(16)]).join();
    }
    // 8-4-4-4-12 with version 4 and variant 8,9,a,b
    final part1 = block(8);
    final part2 = block(4);
    final part3 = (rnd.nextInt(0x1000) | 0x4000).toRadixString(16).padLeft(4, '0');
    final variant = (rnd.nextInt(0x4000) | 0x8000); // 10xx variant
    final part4 = variant.toRadixString(16).padLeft(4, '0');
    final part5 = block(12);
    return '$part1-$part2-$part3-$part4-$part5';
  }
}

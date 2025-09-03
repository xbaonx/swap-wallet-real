import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Centralized runtime config fetched from backend `/api/config`.
/// Falls back to .env when backend is not configured or unreachable.
class ConfigService {
  final String _backendBase = dotenv.env['BACKEND_BASE_URL'] ?? '';
  final String? _envTransakUrl = dotenv.env['TRANSAK_BUY_URL'];
  final String? _envRampUrl = dotenv.env['RAMP_BUY_URL'] ?? dotenv.env['BUY_URL'];

  String? _transakBuyUrl; // cached latest value
  String? _rampBuyUrl; // cached latest value

  /// Load/refresh config from backend. Safe to call multiple times.
  Future<void> refresh() async {
    if (_backendBase.isEmpty) {
      // No backend configured, keep env as source of truth
      _transakBuyUrl ??= _envTransakUrl;
      _rampBuyUrl ??= _envRampUrl;
      return;
    }
    final url = Uri.parse('$_backendBase/api/config');
    try {
      final resp = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = (data['features'] as Map?) ?? const {};
        final t = features['transak_buy_url'];
        if (t is String && t.isNotEmpty) {
          _transakBuyUrl = t;
        }
        final r = features['ramp_buy_url'];
        if (r is String && r.isNotEmpty) {
          _rampBuyUrl = r;
        }
      }
      // fallback
      _transakBuyUrl ??= _envTransakUrl;
      _rampBuyUrl ??= _envRampUrl;
    } catch (_) {
      _transakBuyUrl ??= _envTransakUrl;
      _rampBuyUrl ??= _envRampUrl;
    }
  }

  String? get transakBuyUrl => _transakBuyUrl ?? _envTransakUrl;
  String? get rampBuyUrl => _rampBuyUrl ?? _envRampUrl;
}

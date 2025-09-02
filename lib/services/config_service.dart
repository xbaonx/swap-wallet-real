import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Centralized runtime config fetched from backend `/api/config`.
/// Falls back to .env when backend is not configured or unreachable.
class ConfigService {
  final String _backendBase = dotenv.env['BACKEND_BASE_URL'] ?? '';
  final String? _envTransakUrl =
      dotenv.env['TRANSAK_BUY_URL'] ?? dotenv.env['BUY_URL'];

  String? _transakBuyUrl; // cached latest value

  /// Load/refresh config from backend. Safe to call multiple times.
  Future<void> refresh() async {
    if (_backendBase.isEmpty) {
      // No backend configured, keep env as source of truth
      _transakBuyUrl ??= _envTransakUrl;
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
        final v = features['transak_buy_url'];
        if (v is String && v.isNotEmpty) {
          _transakBuyUrl = v;
          return;
        }
      }
      // fallback
      _transakBuyUrl ??= _envTransakUrl;
    } catch (_) {
      _transakBuyUrl ??= _envTransakUrl;
    }
  }

  String? get transakBuyUrl => _transakBuyUrl ?? _envTransakUrl;
}

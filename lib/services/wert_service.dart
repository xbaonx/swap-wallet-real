import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/errors.dart';
import 'models/wert_models.dart';

/// Wert Fiat Onramp integration helper.
/// Note: Wert requires creating a session on your backend using their Partner API.
/// This service expects a backend endpoint to proxy that request securely.
class WertService {
  final String _partnerId = dotenv.env['WERT_PARTNER_ID'] ?? '';
  final String _env = (dotenv.env['WERT_ENV'] ?? 'sandbox').toLowerCase();
  final String _backendBaseUrl = dotenv.env['WERT_BACKEND_BASE_URL'] ?? '';
  final String _redirectUrl = dotenv.env['WERT_REDIRECT_URL'] ?? 'https://example.com/wert_return';

  bool get isSandbox => !(_env == 'prod' || _env == 'production');
  String get partnerId => _partnerId;
  String get redirectUrl => _redirectUrl;
  String get widgetOrigin => isSandbox ? 'https://sandbox.wert.io' : 'https://widget.wert.io';

  /// Create Wert session via your backend.
  /// - In sandbox, Wert supports Test Token 'TT' on 'bsc'.
  /// - In production, use 'USDT' on 'bsc'.
  Future<String> createSession({
    required String walletAddress,
    double? currencyAmountUsd,
  }) async {
    if (_backendBaseUrl.isEmpty) {
      throw AppError.unknown('Missing WERT_BACKEND_BASE_URL in .env');
    }
    if (_partnerId.isEmpty) {
      throw AppError.unknown('Missing WERT_PARTNER_ID in .env');
    }

    final url = Uri.parse('$_backendBaseUrl/api/wert/create-session');
    final payload = <String, dynamic>{
      'flow_type': 'simple_full_restrict',
      'wallet_address': walletAddress,
      'currency': 'USD',
      'commodity': isSandbox ? 'TT' : 'USDT',
      'network': 'bsc',
      if (currencyAmountUsd != null) 'currency_amount': currencyAmountUsd,
    };

    developer.log('Creating Wert session via backend: $url payload=$payload', name: 'wert');

    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Deterministic idempotency key to avoid duplicate sessions on retries
          'x-idempotency-key': [
            'wert',
            _env,
            walletAddress.toLowerCase(),
            (isSandbox ? 'TT' : 'USDT'),
            'bsc',
            if (currencyAmountUsd != null) currencyAmountUsd.toStringAsFixed(2) else 'na',
          ].join(':'),
        },
        body: jsonEncode(payload),
      );
      if (resp.statusCode != 200) {
        developer.log('Wert session failed: ${resp.statusCode} ${resp.body}', name: 'wert');
        throw AppError.unknown('Failed to create Wert session (${resp.statusCode})');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final sessionId = data['sessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        throw AppError.unknown('Invalid Wert session response');
      }
      return sessionId;
    } catch (e) {
      rethrow;
    }
  }

  /// List Wert sessions for a wallet via backend.
  Future<List<WertSession>> listSessions({required String walletAddress}) async {
    if (_backendBaseUrl.isEmpty) {
      throw AppError.unknown('Missing WERT_BACKEND_BASE_URL in .env');
    }
    final url = Uri.parse('$_backendBaseUrl/api/wert/sessions?wallet=${walletAddress.toLowerCase()}');
    try {
      final resp = await http.get(url, headers: const {'Accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw AppError.unknown('Failed to load Wert sessions (${resp.statusCode})');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['sessions'] as List?) ?? const [];
      return list.map((e) => WertSession.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// List Wert sessions with pagination (limit, cursor in ms) via backend.
  Future<PaginatedSessions> listSessionsPaginated({
    required String walletAddress,
    int limit = 50,
    int? cursorMs,
  }) async {
    if (_backendBaseUrl.isEmpty) {
      throw AppError.unknown('Missing WERT_BACKEND_BASE_URL in .env');
    }
    final qp = <String, String>{
      'wallet': walletAddress.toLowerCase(),
      'limit': limit.clamp(1, 100).toString(),
      if (cursorMs != null) 'cursor': cursorMs.toString(),
    };
    final url = Uri.parse('$_backendBaseUrl/api/wert/sessions').replace(queryParameters: qp);
    try {
      final resp = await http.get(url, headers: const {'Accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw AppError.unknown('Failed to load Wert sessions (${resp.statusCode})');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return PaginatedSessions.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Get Wert session detail (with recent webhooks) via backend.
  Future<WertSessionDetail> getSessionDetail({required String sessionId}) async {
    if (_backendBaseUrl.isEmpty) {
      throw AppError.unknown('Missing WERT_BACKEND_BASE_URL in .env');
    }
    final url = Uri.parse('$_backendBaseUrl/api/wert/sessions/$sessionId');
    try {
      final resp = await http.get(url, headers: const {'Accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw AppError.unknown('Failed to load Wert session detail (${resp.statusCode})');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return WertSessionDetail.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }
}

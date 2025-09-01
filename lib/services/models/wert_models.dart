import 'dart:convert';

class WertSession {
  final String sessionId;
  final String env;
  final String commodity;
  final String currency;
  final double? currencyAmount;
  final String network;
  final String status;
  final Map<String, dynamic>? meta;
  final int createdAt;
  final int updatedAt;

  WertSession({
    required this.sessionId,
    required this.env,
    required this.commodity,
    required this.currency,
    required this.currencyAmount,
    required this.network,
    required this.status,
    required this.meta,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WertSession.fromJson(Map<String, dynamic> j) {
    return WertSession(
      sessionId: (j['session_id'] ?? j['sessionId'] ?? j['id'] ?? '').toString(),
      env: (j['env'] ?? 'sandbox').toString(),
      commodity: (j['commodity'] ?? '').toString(),
      currency: (j['currency'] ?? '').toString(),
      currencyAmount: j['currency_amount'] == null
          ? null
          : (j['currency_amount'] is num
              ? (j['currency_amount'] as num).toDouble()
              : double.tryParse(j['currency_amount'].toString())),
      network: (j['network'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      meta: _parseMeta(j['meta']),
      createdAt: _toIntMs(j['created_at']),
      updatedAt: _toIntMs(j['updated_at']),
    );
  }

  static Map<String, dynamic>? _parseMeta(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static int _toIntMs(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class WertWebhook {
  final String eventType;
  final Map<String, dynamic>? payload;
  final int createdAt;

  WertWebhook({
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  factory WertWebhook.fromJson(Map<String, dynamic> j) {
    return WertWebhook(
      eventType: (j['event_type'] ?? j['type'] ?? j['event'] ?? 'unknown').toString(),
      payload: _parsePayload(j['payload']),
      createdAt: WertSession._toIntMs(j['created_at']),
    );
  }

  static Map<String, dynamic>? _parsePayload(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }
}

class WertSessionDetail {
  final WertSession session;
  final List<WertWebhook> webhooks;

  WertSessionDetail({
    required this.session,
    required this.webhooks,
  });

  factory WertSessionDetail.fromJson(Map<String, dynamic> j) {
    final s = j['session'] as Map<String, dynamic>? ?? const {};
    final hooks = (j['webhooks'] as List?) ?? const [];
    return WertSessionDetail(
      session: WertSession.fromJson(s),
      webhooks: hooks.map((e) => WertWebhook.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PaginatedSessions {
  final List<WertSession> sessions;
  final int? nextCursor;

  PaginatedSessions({
    required this.sessions,
    required this.nextCursor,
  });

  factory PaginatedSessions.fromJson(Map<String, dynamic> j) {
    final list = (j['sessions'] as List?) ?? const [];
    final items = list.map((e) => WertSession.fromJson(e as Map<String, dynamic>)).toList();
    int? nc;
    final raw = j['nextCursor'];
    if (raw is int) nc = raw;
    else if (raw is num) nc = raw.toInt();
    else if (raw is String) nc = int.tryParse(raw);
    return PaginatedSessions(sessions: items, nextCursor: nc);
  }
}

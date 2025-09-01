import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/i18n.dart';
import '../../core/format.dart';
import '../../core/service_locator.dart';
import '../../services/models/wert_models.dart';

class WertSessionDetailScreen extends StatefulWidget {
  final String sessionId;
  const WertSessionDetailScreen({super.key, required this.sessionId});

  @override
  State<WertSessionDetailScreen> createState() => _WertSessionDetailScreenState();
}

class _WertSessionDetailScreenState extends State<WertSessionDetailScreen> {
  late Future<WertSessionDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WertSessionDetail> _load() async {
    final locator = ServiceLocator();
    return locator.wertService.getSessionDetail(sessionId: widget.sessionId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppI18n.tr(context, 'wert.detail.title')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppI18n.tr(context, 'wert.refresh'),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<WertSessionDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snap.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: Text(AppI18n.tr(context, 'wert.refresh')),
                    ),
                  ],
                ),
              ),
            );
          }
          final detail = snap.data!;
          final s = detail.session;
          final dtCreated = DateTime.fromMillisecondsSinceEpoch(s.createdAt, isUtc: false);
          final dtUpdated = DateTime.fromMillisecondsSinceEpoch(s.updatedAt, isUtc: false);
          final createdStr = DateFormat('yyyy-MM-dd HH:mm').format(dtCreated);
          final updatedStr = DateFormat('yyyy-MM-dd HH:mm').format(dtUpdated);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: const Color(0xFF101418),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rowKV(AppI18n.tr(context, 'wert.detail.session_id'), s.sessionId),
                        const SizedBox(height: 8),
                        _rowKV(AppI18n.tr(context, 'wert.detail.status'), _statusLabel(s.status)),
                        const SizedBox(height: 8),
                        _rowKV(AppI18n.tr(context, 'wert.detail.amount'), s.currencyAmount == null ? '—' : AppFormat.formatUsdt(s.currencyAmount!)),
                        const SizedBox(height: 8),
                        _rowKV(AppI18n.tr(context, 'wert.detail.network'), s.network.toUpperCase()),
                        const SizedBox(height: 8),
                        _rowKV(AppI18n.tr(context, 'wert.detail.created_at'), createdStr),
                        const SizedBox(height: 8),
                        _rowKV(AppI18n.tr(context, 'wert.detail.updated_at'), updatedStr),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppI18n.tr(context, 'wert.webhooks.title'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (detail.webhooks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(AppI18n.tr(context, 'wert.webhooks.empty'), style: const TextStyle(color: Colors.white70)),
                  )
                else
                  Card(
                    elevation: 0,
                    color: const Color(0xFF101418),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: detail.webhooks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1C2229)),
                      itemBuilder: (context, index) {
                        final w = detail.webhooks[index];
                        final t = DateTime.fromMillisecondsSinceEpoch(w.createdAt, isUtc: false);
                        final tStr = DateFormat('dd/MM HH:mm').format(t);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.event, size: 18),
                          title: Text(w.eventType),
                          subtitle: Text(tStr),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            _showPayload(context, w);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(String status) {
    final st = status.toLowerCase();
    if (st.contains('complete') || st == 'paid' || st == 'confirmed') {
      return 'Hoàn tất';
    } else if (st.contains('fail') || st == 'canceled') {
      return 'Hủy/Thất bại';
    }
    return 'Đang xử lý';
  }

  Widget _rowKV(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.white70))),
        const SizedBox(width: 8),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }

  void _showPayload(BuildContext context, WertWebhook w) {
    final pretty = w.payload?.toString() ?? '{}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1317),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.data_object),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Webhook: ${w.eventType}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(pretty),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

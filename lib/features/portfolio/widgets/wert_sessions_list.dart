import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/i18n.dart';
import '../../../core/service_locator.dart';
import '../../../services/models/wert_models.dart';
import '../wert_session_detail_screen.dart';
import '../wert_sessions_history_screen.dart';

class WertSessionsList extends StatefulWidget {
  final int maxItems;
  const WertSessionsList({super.key, this.maxItems = 5});

  @override
  State<WertSessionsList> createState() => _WertSessionsListState();
}

class _WertSessionsListState extends State<WertSessionsList> {
  late Future<List<WertSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WertSession>> _load() async {
    try {
      final locator = ServiceLocator();
      final wallet = await locator.walletService.getAddress();
      final sessions = await locator.wertService.listSessions(walletAddress: wallet);
      if (sessions.length > widget.maxItems) {
        return sessions.take(widget.maxItems).toList();
      }
      return sessions;
    } catch (e) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WertSession>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(AppI18n.tr(context, 'wert.title'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WertSessionsHistoryScreen()),
                      );
                    },
                    child: Text(AppI18n.tr(context, 'wert.view_all')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: AppI18n.tr(context, 'wert.refresh'),
                    onPressed: _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: const Color(0xFF101418),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1C2229)),
                  itemBuilder: (context, index) {
                    final s = items[index];
                    final dt = DateTime.fromMillisecondsSinceEpoch(s.createdAt, isUtc: false);
                    final dtStr = DateFormat('dd/MM HH:mm').format(dt);
                    final amountStr = s.currencyAmount == null ? '—' : AppFormat.formatUsdt(s.currencyAmount!);

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF1F2630),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.white70),
                      ),
                      title: Text('${s.commodity} • ${s.currency} $amountStr', style: const TextStyle(fontSize: 14)),
                      subtitle: Text('$dtStr • ${s.network.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      trailing: _StatusChip(status: s.status),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => WertSessionDetailScreen(sessionId: s.sessionId)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final st = status.toLowerCase();
    Color bg;
    Color fg;
    String label = status;
    if (st.contains('complete') || st == 'paid' || st == 'confirmed') {
      bg = const Color(0xFF103B22);
      fg = const Color(0xFF3DDC84);
      label = 'Hoàn tất';
    } else if (st.contains('fail') || st == 'canceled') {
      bg = const Color(0xFF3A1A1A);
      fg = const Color(0xFFFF6B6B);
      label = 'Hủy/Thất bại';
    } else {
      bg = const Color(0xFF1E2A38);
      fg = const Color(0xFF69A7FF);
      label = 'Đang xử lý';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

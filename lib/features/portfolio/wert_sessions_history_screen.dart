import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/i18n.dart';
import '../../core/format.dart';
import '../../core/service_locator.dart';
import '../../services/models/wert_models.dart';
import 'wert_session_detail_screen.dart';

class WertSessionsHistoryScreen extends StatefulWidget {
  const WertSessionsHistoryScreen({super.key});

  @override
  State<WertSessionsHistoryScreen> createState() => _WertSessionsHistoryScreenState();
}

class _WertSessionsHistoryScreenState extends State<WertSessionsHistoryScreen> {
  final _controller = ScrollController();
  final _items = <WertSession>[];
  int? _nextCursor;
  bool _loading = false;
  bool _initialLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _nextCursor = null;
      _error = null;
      _initialLoaded = false;
    });
    await _fetchMore(reset: true);
  }

  Future<void> _fetchMore({bool reset = false}) async {
    if (_loading) return;
    if (_initialLoaded && _nextCursor == null && !reset) return;
    setState(() => _loading = true);
    try {
      final locator = ServiceLocator();
      final wallet = await locator.walletService.getAddress();
      final page = await locator.wertService.listSessionsPaginated(
        walletAddress: wallet,
        limit: 20,
        cursorMs: reset ? null : _nextCursor,
      );
      setState(() {
        _items.addAll(page.sessions);
        _nextCursor = page.nextCursor;
        _initialLoaded = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppI18n.tr(context, 'wert.title');
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1C2229)),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              if (!_initialLoaded && _loading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (_error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _fetchMore,
                        child: Text(AppI18n.tr(context, 'wert.refresh')),
                      ),
                    ],
                  ),
                );
              }
              if (_nextCursor == null) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final s = _items[index];
            final dt = DateTime.fromMillisecondsSinceEpoch(s.createdAt, isUtc: false);
            final dtStr = DateFormat('dd/MM HH:mm').format(dt);
            final amountStr = s.currencyAmount == null ? '—' : AppFormat.formatUsdt(s.currencyAmount!);

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1F2630),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.white70),
              ),
              title: Text('${s.commodity} • ${s.currency} $amountStr'),
              subtitle: Text('$dtStr • ${s.network.toUpperCase()}'),
              trailing: _WertStatusChip(status: s.status),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WertSessionDetailScreen(sessionId: s.sessionId)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WertStatusChip extends StatelessWidget {
  final String status;
  const _WertStatusChip({required this.status});

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

import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/position.dart';
import '../../../storage/prefs_store.dart';

class _Avatar extends StatelessWidget {
  final String base;
  final double size;
  const _Avatar(this.base, {this.size = 36});
  @override
  Widget build(BuildContext context) {
    final label = base.length > 3 ? base.substring(0, 3) : base;
    return CircleAvatar(
      radius: size / 2,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

Future<void> showSellSheet({
  required BuildContext context,
  required String base,
  required double bid,
  required Position position,
  required PortfolioEngine engine,
  required PrefsStore prefsStore,
}) async {
  final ctl = TextEditingController();
  final qtyNotifier = ValueNotifier<double>(0.0);
  
  // Update notifier when text changes
  void updateQty() {
    qtyNotifier.value = double.tryParse(ctl.text.trim()) ?? 0.0;
  }
  
  ctl.addListener(updateQty);
  
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtl) {
          final qtyAvail = position.qty;
          final avg = position.avgEntry;
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: ListView(
              controller: scrollCtl,
              children: [
                Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                )),
                const SizedBox(height: 12),
                Row(children: [
                  _Avatar(base, size: 36),
                  const SizedBox(width: 10),
                  Text(base, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${AppFormat.formatUsdt(bid)} USDT',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                Text('Số dư: ${qtyAvail.toStringAsFixed(6)} $base • Avg: ${AppFormat.formatUsdt(avg)} USDT',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                TextField(
                  controller: ctl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Nhập số $base muốn bán',
                    helperText: 'Phí ${(AppConstants.tradingFee * 100).toStringAsFixed(1)}%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [25, 50, 75, 100].map((p) {
                  return OutlinedButton(
                    onPressed: () {
                      final v = qtyAvail * p / 100.0;
                      // Đảm bảo không vượt quá số lượng thực tế
                      final safeValue = v > qtyAvail ? qtyAvail : v;
                      ctl.text = safeValue.toStringAsFixed(6);
                    },
                    child: Text('$p%'),
                  );
                }).toList()),
                const SizedBox(height: 8),
                ValueListenableBuilder<double>(
                  valueListenable: qtyNotifier,
                  builder: (context, qty, child) {
                    final fee = AppConstants.tradingFee;
                    final can = qty > 0 && qtyAvail >= qty - 1e-6 && bid > 0;
                    final usdtOut = can ? (qty * bid) * (1 - fee) : 0.0;
                    final realized = can ? usdtOut - qty * avg : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (can)
                          Text('Nhận ~ ${AppFormat.formatUsdt(usdtOut)} USDT • Realized P&L: ${AppFormat.formatUsdt(realized)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48, width: double.infinity,
                          child: FilledButton(
                            onPressed: can ? () async {
                              final v = double.tryParse(ctl.text.trim()) ?? 0.0;
                              if (v <= 0) return;
                              
                              dev.log('🔍 SELL DEBUG: Bắt đầu bán $v $base');
                              dev.log('🔍 SELL DEBUG: Position trước khi bán: ${position.qty}');
                              
                              final result = engine.sellOrder(base, v, bid);
                              dev.log('🔍 SELL DEBUG: Kết quả sellOrder: ${result.ok}');
                              
                              if (result.ok) {
                                try {
                                  await prefsStore.recordSell(
                                    base: base, qty: v, price: bid, feeRate: fee,
                                    usdtOut: result.usdt, realizedPnL: result.realized ?? 0.0,
                                  );
                                  dev.log('🔍 SELL DEBUG: Đã ghi trade history');
                                } catch (e) {
                                  dev.log('🔍 SELL DEBUG: Lỗi ghi trade history: $e');
                                }
                                
                                await prefsStore.commitNow(engine.currentPortfolio);
                                dev.log('🔍 SELL DEBUG: Đã commit portfolio');
                                
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã bán ${v.toStringAsFixed(6)} $base')),
                                  );
                                }
                              } else {
                                dev.log('🔍 SELL DEBUG: Bán thất bại!');
                              }
                            } : null,
                            child: const Text('Bán'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    ctl.removeListener(updateQty);
    qtyNotifier.dispose();
  });
}

import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../domain/logic/portfolio_engine.dart';
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

Future<void> showSwapSheet({
  required BuildContext context,
  required String base,
  required double ask,
  required double usdtBalance,
  required PortfolioEngine engine,
  required PrefsStore prefsStore,
  VoidCallback? onRequestSellOnDashboard,
}) async {
  final ctl = TextEditingController();
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
                  Text('${AppFormat.formatUsdt(ask)} USDT',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                Text('Mua (USDT → $base)', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                TextField(
                  controller: ctl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Nhập số USDT',
                    helperText: 'Số dư: ${AppFormat.formatUsdt(usdtBalance)} • Phí ${(AppConstants.tradingFee * 100).toStringAsFixed(1)}%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  onChanged: (_) => (ctx as Element).markNeedsBuild(),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final p in AppConstants.quickPercentages)
                    OutlinedButton(
                      onPressed: () {
                        final v = usdtBalance * p / 100.0;
                        // Đảm bảo không vượt quá số dư thực tế
                        final safeValue = v > usdtBalance ? usdtBalance : v;
                        ctl.text = safeValue.toStringAsFixed(2);
                        (ctx as Element).markNeedsBuild();
                      },
                      child: Text('$p%'),
                    ),
                ]),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final fee = AppConstants.tradingFee;
                  final usdtIn = double.tryParse(ctl.text.trim()) ?? 0.0;
                  final can = usdtIn > 0 && usdtBalance >= usdtIn - 0.01 && ask > 0;
                  final est = can ? (usdtIn / ask) * (1 - fee) : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (can)
                        Text('Nhận ~ ${est.toStringAsFixed(6)} $base (sau phí)',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48, width: double.infinity,
                        child: FilledButton(
                          onPressed: can ? () async {
                            final v = double.tryParse(ctl.text.trim()) ?? 0.0;
                            if (v <= 0) return;
                            
                            print('🔍 BUY DEBUG: Bắt đầu mua $base với ${AppFormat.formatUsdt(v)} USDT');
                            print('🔍 BUY DEBUG: Số dư USDT trước khi mua: ${usdtBalance}');
                            
                            final result = engine.buyOrder(base, v, ask);
                            print('🔍 BUY DEBUG: Kết quả buyOrder: ${result.ok}');
                            
                            if (result.ok) {
                              try {
                                await prefsStore.recordBuy(
                                  base: base, qty: result.qty,
                                  price: ask, feeRate: fee, usdtIn: v,
                                );
                                print('🔍 BUY DEBUG: Đã ghi trade history');
                              } catch (e) {
                                print('🔍 BUY DEBUG: Lỗi ghi trade history: $e');
                              }
                              
                              await prefsStore.commitNow(engine.currentPortfolio);
                              print('🔍 BUY DEBUG: Đã commit portfolio');
                              
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Đã mua $base trị giá ${AppFormat.formatUsdt(v)} USDT')),
                                );
                              }
                            } else {
                              print('🔍 BUY DEBUG: Mua thất bại!');
                            }
                          } : null,
                          child: const Text('Mua'),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                if (onRequestSellOnDashboard != null)
                  TextButton.icon(
                    onPressed: onRequestSellOnDashboard,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Bán trên Dashboard'),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'dart:math' as math;
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../core/i18n.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/position.dart';
import '../../../storage/prefs_store.dart';
import '../../../core/service_locator.dart';
import '../../../core/errors.dart';

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

String _errorTextFromAppError(BuildContext ctx, AppError e) {
  switch (e.code) {
    case AppErrorCode.walletLocked:
      return AppI18n.tr(ctx, 'trade.error.wallet_locked');
    case AppErrorCode.allowanceRequired:
      return AppI18n.tr(ctx, 'trade.error.allowance_required');
    case AppErrorCode.insufficientFunds:
      return AppI18n.tr(ctx, 'trade.error.insufficient_funds');
    case AppErrorCode.slippageExceeded:
      return AppI18n.tr(ctx, 'trade.error.slippage_exceeded');
    case AppErrorCode.networkError:
      return AppI18n.tr(ctx, 'trade.error.network_error');
    case AppErrorCode.timeout:
      return AppI18n.tr(ctx, 'trade.error.timeout');
    case AppErrorCode.rateLimited:
      return AppI18n.tr(ctx, 'trade.error.rate_limited');
    case AppErrorCode.rpcSwitched:
      return AppI18n.tr(ctx, 'trade.error.rpc_switched');
    case AppErrorCode.swapFailed:
    case AppErrorCode.unknown:
    default:
      return '${AppI18n.tr(ctx, 'trade.error.swap_failed_prefix')} ${e.message}';
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
      return FutureBuilder<double>(
        future: ServiceLocator().swapAdapter.getOnchainBalance(base),
        builder: (onchainCtx, snapshot) {
          final onchainQty = snapshot.hasData ? (snapshot.data ?? 0.0) : 0.0; // 0 trong lúc loading
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            builder: (ctx, scrollCtl) {
              // Sử dụng số dư on-chain để gate, tránh sai lệch với portfolio
              final qtyAvail = onchainQty;
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
                Text('${AppI18n.tr(ctx, 'trade.onchain_balance')} ${qtyAvail.toStringAsFixed(6)} $base • ${AppI18n.tr(ctx, 'trade.avg')}: ${AppFormat.formatUsdt(avg)} USDT',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                TextField(
                  controller: ctl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${AppI18n.tr(ctx, 'trade.input.sell_amount_prefix')} $base',
                    helperText: '${AppI18n.tr(ctx, 'trade.fee')} ${(AppConstants.tradingFee * 100).toStringAsFixed(1)}%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [25, 50, 75, 100].map((p) {
                  return OutlinedButton(
                    onPressed: () {
                      // Tính target rồi làm tròn xuống 6 số thập phân để không vượt số dư
                      final registry = ServiceLocator().tokenRegistry;
                      final token = registry.getBySymbol(base);
                      final tokenAddress = registry.getTokenAddress(base) ?? '';
                      final isNative = tokenAddress.toLowerCase() == '0x0000000000000000000000000000000000000000' ||
                          tokenAddress.toLowerCase() == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
                      final chainDecimals = token?.decimals ?? 18;
                      final oneWeiUnit = 1.0 / math.pow(10, chainDecimals);
                      const displayDecimals = 6;
                      double target = qtyAvail * p / 100.0;
                      if (p == 100 && isNative) {
                        // Với Max của native, trừ 1 wei trước rồi floor để tránh round-up vượt số dư
                        target = (qtyAvail - oneWeiUnit).clamp(0.0, qtyAvail).toDouble();
                      }
                      final m = math.pow(10, displayDecimals).toDouble();
                      final floored = (target * m).floor() / m;
                      ctl.text = floored.toStringAsFixed(displayDecimals);
                    },
                    child: Text('$p%'),
                  );
                }).toList()),
                const SizedBox(height: 8),
                ValueListenableBuilder<double>(
                  valueListenable: qtyNotifier,
                  builder: (context, qty, child) {
                    final fee = AppConstants.tradingFee;
                    // Tính safe max theo on-chain: trừ 1 wei và floor 6 số thập phân
                    final registry = ServiceLocator().tokenRegistry;
                    final token = registry.getBySymbol(base);
                    final tokenAddress = registry.getTokenAddress(base) ?? '';
                    final isNative = tokenAddress.toLowerCase() == '0x0000000000000000000000000000000000000000' ||
                        tokenAddress.toLowerCase() == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
                    final chainDecimals = token?.decimals ?? 18;
                    final oneWeiUnit = 1.0 / math.pow(10, chainDecimals);
                    const displayDecimals = 6;
                    final m = math.pow(10, displayDecimals).toDouble();
                    final safeMaxTarget = isNative
                        ? (qtyAvail - oneWeiUnit).clamp(0.0, qtyAvail).toDouble()
                        : qtyAvail;
                    final safeMax = (safeMaxTarget * m).floor() / m;
                    final can = qty > 0 && qty <= safeMax && bid > 0;
                    final usdtOut = can ? (qty * bid) * (1 - fee) : 0.0;
                    final realized = can ? usdtOut - qty * avg : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (can)
                          Text('${AppI18n.tr(ctx, 'trade.estimate.receive_prefix')} ${AppFormat.formatUsdt(usdtOut)} USDT • ${AppI18n.tr(ctx, 'trade.realized_pnl')}: ${AppFormat.formatUsdt(realized)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48, width: double.infinity,
                          child: FilledButton(
                            onPressed: can ? () async {
                              final v = double.tryParse(ctl.text.trim()) ?? 0.0;
                              if (v <= 0) return;
                              
                              dev.log('🔍 SELL DEBUG: Bắt đầu bán $v $base');
                              dev.log('🔍 SELL DEBUG: Số dư $base on-chain trước khi bán: $qtyAvail');

                              // Hiển thị dialog tiến trình khi thực hiện swap on-chain
                              showDialog(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (_) => AlertDialog(
                                  content: SizedBox(
                                    height: 64,
                                    child: Row(
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(width: 16),
                                        Expanded(child: Text(AppI18n.tr(ctx, 'trade.progress.swapping'))),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              final adapter = ServiceLocator().swapAdapter;
                              TradeExecResult result;
                              try {
                                result = await adapter.executeSwap(
                                  fromSymbol: base,
                                  toSymbol: 'USDT',
                                  amount: v,
                                );
                                dev.log('🔍 SELL DEBUG: Swap result ok=${result.ok}, qty=${result.qty}, price=${result.price}, usdt=${result.usdt}');
                              } catch (e) {
                                dev.log('🔍 SELL DEBUG: Swap exception: $e');
                                // Đóng dialog tiến trình trước khi báo lỗi
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                }
                                String msg;
                                if (e is AppError) {
                                  msg = _errorTextFromAppError(ctx, e);
                                } else {
                                  msg = '${AppI18n.tr(ctx, 'trade.error.swap_failed_prefix')} $e';
                                }
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(msg)),
                                  );
                                }
                                return; // thoát sớm khi lỗi
                              }

                              // Đóng dialog tiến trình
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }

                              if (result.ok) {
                                final usdtOut = result.usdt; // Adapter trả về USDT nhận được khi from != USDT
                                final priceUsdtPerCoin = v > 0 ? (usdtOut / v) : bid;
                                final realizedPnL = usdtOut - v * avg;
                                try {
                                  await prefsStore.recordSell(
                                    base: base,
                                    qty: v,
                                    price: priceUsdtPerCoin,
                                    feeRate: result.feeRate,
                                    usdtOut: usdtOut,
                                    realizedPnL: realizedPnL,
                                  );
                                  dev.log('🔍 SELL DEBUG: Đã ghi trade history (on-chain)');
                                } catch (e) {
                                  dev.log('🔍 SELL DEBUG: Lỗi ghi trade history: $e');
                                }

                                await prefsStore.commitNow(engine.currentPortfolio);
                                dev.log('🔍 SELL DEBUG: Đã commit portfolio');

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${AppI18n.tr(ctx, 'trade.snackbar.sold_prefix')} ${v.toStringAsFixed(6)} $base')),
                                  );
                                }
                              } else {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppI18n.tr(ctx, 'trade.snackbar.swap_failed'))),
                                  );
                                }
                                dev.log('🔍 SELL DEBUG: Bán thất bại!');
                              }
                            } : null,
                            child: Text(AppI18n.tr(ctx, 'trade.sell')),
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
      );
    },
  );
  ctl.removeListener(updateQty);
  qtyNotifier.dispose();
}

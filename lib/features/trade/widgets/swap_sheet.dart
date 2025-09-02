import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'dart:math' as math;
import 'dart:async';
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../core/i18n.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../storage/prefs_store.dart';
import '../../../core/service_locator.dart';
import '../../../core/errors.dart';
import '../../../data/token/token_registry.dart';

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
  Timer? debounce;
  double usdtInDebounced = 0.0;

  // Helpers: resolve symbol to 1inch token, pricing and quoting via 1inch
  final tokenRegistry = ServiceLocator().tokenRegistry;

  TokenInfo? resolveToken(String symbol) {
    // Try direct
    final direct = tokenRegistry.getBySymbol(symbol);
    if (direct != null) return direct;
    // Try fuzzy by symbol then by name
    final upper = symbol.toUpperCase();
    final all = tokenRegistry.getAllTokens();
    final exact = all.where((t) => t.symbol.toUpperCase() == upper).toList();
    if (exact.isNotEmpty) return exact.first;
    final contains = all.where((t) => t.symbol.toUpperCase().contains(upper)).toList();
    if (contains.isNotEmpty) return contains.first;
    final nameMatch = all.where((t) => t.name.toUpperCase().contains(upper)).toList();
    if (nameMatch.isNotEmpty) return nameMatch.first;
    return null;
  }

  Future<double?> oneInchPriceUsdtPerToken(TokenInfo token) async {
    try {
      final usdt = tokenRegistry.getBySymbol('USDT');
      if (usdt == null) return null;
      final inch = ServiceLocator().inchClient;
      final amountWei = BigInt.from(10).pow(token.decimals).toString(); // 1 token
      final q = await inch.quote(
        fromTokenAddress: token.address,
        toTokenAddress: usdt.address,
        amountWei: amountWei,
      );
      final usdtOutWei = q.dstAmount;
      final usdtOut = double.tryParse(usdtOutWei) ?? 0.0;
      return usdtOut / math.pow(10, usdt.decimals);
    } catch (e) {
      dev.log('🔍 1inch price error ($base): $e');
      return null;
    }
  }

  Future<double> oneInchQuoteTokensOut({required double usdtIn, required TokenInfo token}) async {
    try {
      final usdt = tokenRegistry.getBySymbol('USDT');
      if (usdt == null) return 0.0;
      final inch = ServiceLocator().inchClient;
      final amountWei = (usdtIn * math.pow(10, usdt.decimals)).round().toString();
      final q = await inch.quote(
        fromTokenAddress: usdt.address,
        toTokenAddress: token.address,
        amountWei: amountWei,
      );
      final tokenOutWei = q.dstAmount;
      final tokenOut = double.tryParse(tokenOutWei) ?? 0.0;
      return tokenOut / math.pow(10, token.decimals);
    } catch (e) {
      dev.log('🔍 1inch quote error ($base): $e');
      return 0.0;
    }
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return FutureBuilder<double>(
        future: ServiceLocator().swapAdapter.getOnchainBalance('USDT'),
        builder: (onchainCtx, snapshot) {
          // Trong khi chưa tải xong số dư on-chain, coi như 0 để tránh bật nút mua sai
          final effectiveUsdt = snapshot.hasData ? (snapshot.data ?? 0.0) : 0.0;
          final resolved = resolveToken(base);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            builder: (ctx, scrollCtl) {
              return StatefulBuilder(
                builder: (sbCtx, setState) {
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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(base, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (resolved != null && resolved.symbol.toUpperCase() != base.toUpperCase())
                      Text('${AppI18n.tr(ctx, 'trade.oneinch_symbol_prefix')} ${resolved.symbol}', style: Theme.of(ctx).textTheme.bodySmall),
                    if (resolved == null)
                      Text(AppI18n.tr(ctx, 'trade.oneinch_not_found_bsc'), style: Theme.of(ctx).textTheme.bodySmall),
                  ]),
                  const Spacer(),
                  // Show 1inch price (USDT per 1 token), fallback to ask from screen
                  FutureBuilder<double?>(
                    future: resolved != null ? oneInchPriceUsdtPerToken(resolved) : Future.value(null),
                    builder: (_, snap) {
                      final price = (snap.connectionState == ConnectionState.done && snap.data != null)
                          ? snap.data!
                          : ask;
                      return Text(
                        '${AppFormat.formatUsdt(price)} USDT',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 14),
                Text('${AppI18n.tr(ctx, 'trade.buy')} (USDT → $base)', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                TextField(
                  controller: ctl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: AppI18n.tr(ctx, 'trade.input.usdt_amount'),
                    helperText: '${AppI18n.tr(ctx, 'trade.balance')}: ${AppFormat.formatUsdt(effectiveUsdt)} • ${AppI18n.tr(ctx, 'trade.fee')} ${(AppConstants.tradingFee * 100).toStringAsFixed(1)}%',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    // Rebuild for immediate UI state (button enablement)
                    setState(() {});
                    // Debounce quotes to avoid spamming 1inch
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 350), () {
                      final v = double.tryParse(ctl.text.trim()) ?? 0.0;
                      usdtInDebounced = v;
                      if (sbCtx.mounted) setState(() {});
                    });
                  },
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final p in AppConstants.quickPercentages)
                    OutlinedButton(
                      onPressed: () {
                        final v = effectiveUsdt * p / 100.0;
                        // Đảm bảo không vượt quá số dư thực tế
                        final safeValue = v > effectiveUsdt ? effectiveUsdt : v;
                        ctl.text = safeValue.toStringAsFixed(2);
                        // Trigger debounce immediately for preset buttons
                        debounce?.cancel();
                        usdtInDebounced = double.tryParse(ctl.text.trim()) ?? 0.0;
                        setState(() {});
                      },
                      child: Text('$p%'),
                    ),
                ]),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final usdtIn = double.tryParse(ctl.text.trim()) ?? 0.0;
                  final usdtInQuote = usdtInDebounced;
                  final can = usdtIn > 0 && effectiveUsdt >= usdtIn - 0.01 && resolved != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (can && usdtInQuote > 0)
                        FutureBuilder<double>(
                          future: oneInchQuoteTokensOut(usdtIn: usdtInQuote, token: resolved),
                          builder: (_, snap) {
                            final est = snap.data ?? 0.0;
                            return Text('${AppI18n.tr(ctx, 'trade.estimate.receive_prefix')} ${est.toStringAsFixed(6)} ${resolved.symbol}',
                                style: const TextStyle(fontWeight: FontWeight.w600));
                          },
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48, width: double.infinity,
                        child: FilledButton(
                          onPressed: can ? () async {
                            final v = double.tryParse(ctl.text.trim()) ?? 0.0;
                            if (v <= 0) return;
                            debounce?.cancel();
                            
                            dev.log('🔍 BUY DEBUG: Bắt đầu mua $base với ${AppFormat.formatUsdt(v)} USDT');
                            dev.log('🔍 BUY DEBUG: Số dư USDT trước khi mua (on-chain): $effectiveUsdt');
                            
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
                                fromSymbol: 'USDT',
                                toSymbol: resolved.symbol,
                                amount: v,
                              );
                              if (!ctx.mounted) return;
                              dev.log('🔍 BUY DEBUG: Swap result ok=${result.ok}, qty=${result.qty}, price=${result.price}, usdt=${result.usdt}');
                            } catch (e) {
                              dev.log('🔍 BUY DEBUG: Swap exception: $e');
                              if (!ctx.mounted) return;
                              // Đóng dialog tiến trình trước khi báo lỗi
                              Navigator.of(ctx).pop();
                              String msg;
                              if (e is AppError) {
                                msg = _errorTextFromAppError(ctx, e);
                              } else {
                                msg = '${AppI18n.tr(ctx, 'trade.error.swap_failed_prefix')} $e';
                              }
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                              return; // thoát sớm khi lỗi
                            }

                            // Đóng dialog tiến trình
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();

                            if (result.ok) {
                              try {
                                await prefsStore.recordBuy(
                                  base: base,
                                  qty: result.qty,
                                  price: result.price,
                                  feeRate: result.feeRate,
                                  usdtIn: result.usdt,
                                );
                                dev.log('🔍 BUY DEBUG: Đã ghi trade history (on-chain)');
                              } catch (e) {
                                dev.log('🔍 BUY DEBUG: Lỗi ghi trade history: $e');
                              }

                              // Lưu lại portfolio hiện tại (đồng bộ sẽ được SwapAdapter kích hoạt sau)
                              await prefsStore.commitNow(engine.currentPortfolio);
                              dev.log('🔍 BUY DEBUG: Đã commit portfolio');

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx); // đóng bottom sheet
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('${AppI18n.tr(ctx, 'trade.snackbar.bought_prefix')} $base ${AppI18n.tr(ctx, 'trade.snackbar.for')} ${AppFormat.formatUsdt(result.usdt)} USDT')),
                              );
                            } else {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(AppI18n.tr(ctx, 'trade.snackbar.swap_failed'))),
                              );
                              dev.log('🔍 BUY DEBUG: Mua thất bại!');
                            }
                          } : null,
                          child: Text(AppI18n.tr(ctx, 'trade.buy')),
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
                    label: Text(AppI18n.tr(ctx, 'trade.dashboard.sell_on_dashboard')),
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
    },
  );
  // Clean up any pending debounce timer after sheet closes
  debounce?.cancel();
  ctl.dispose();
}

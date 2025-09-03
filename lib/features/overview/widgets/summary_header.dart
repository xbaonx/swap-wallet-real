import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/i18n.dart';

import '../../../core/format.dart';
import '../../../domain/models/portfolio.dart';
import '../../../core/service_locator.dart';

class SummaryHeader extends StatelessWidget {
  final Portfolio portfolio;
  final Map<String, double> currentPrices;

  const SummaryHeader({
    super.key,
    required this.portfolio,
    required this.currentPrices,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tính riêng giá trị stablecoins và non-stable từ holdings
    const stableSymbols = {'USDT', 'USDC', 'BUSD', 'DAI'};
    double stableValue = 0.0;
    double nonStableValue = 0.0;
    portfolio.positions.forEach((base, position) {
      final price = currentPrices[base] ?? position.avgEntry;
      final value = position.qty * price;
      if (stableSymbols.contains(base.toUpperCase())) {
        stableValue += value;
      } else {
        nonStableValue += value;
      }
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USD (Stable) label (no button here)
          Text(
            AppI18n.tr(context, 'summary.usd_stable'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.left,
          ),
          // Amount row with Deposit button on the right
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${AppFormat.formatUsdt(stableValue)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  // Pre-translate texts to avoid using BuildContext after awaits
                  final invalidAmountText = AppI18n.tr(context, 'deposit.error.invalid_amount');
                  final openProviderText = AppI18n.tr(context, 'deposit.error.open_provider');
                  final openFailedPrefix = AppI18n.tr(context, 'deposit.error.open_failed');
                  try {
                    // Hỏi người dùng số tiền và loại tiền tệ
                    final amountCtrl = TextEditingController(text: '100');
                    String currency = 'USD';
                    final result = await showDialog<Map<String, String>?>(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: Text(AppI18n.tr(context, 'deposit.title')),
                          content: StatefulBuilder(
                            builder: (context, setState) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: amountCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: AppI18n.tr(context, 'deposit.amount')),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(AppI18n.tr(context, 'deposit.currency')),
                                  const SizedBox(height: 6),
                                  ToggleButtons(
                                    isSelected: [currency == 'USD', currency == 'EUR'],
                                    onPressed: (index) {
                                      setState(() {
                                        currency = index == 0 ? 'USD' : 'EUR';
                                      });
                                    },
                                    children: const [
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('USD')),
                                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('EUR')),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(null),
                              child: Text(AppI18n.tr(context, 'common.cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop({ 'amount': amountCtrl.text, 'currency': currency }),
                              child: Text(AppI18n.tr(context, 'deposit.buy')),
                            ),
                          ],
                        );
                      },
                    );
                    if (result == null) return;
                    final amount = double.tryParse(result['amount'] ?? '');
                    final fiatCurrency = (result['currency'] ?? 'USD').toUpperCase();

                    if (amount == null || amount <= 0) {
                      messenger.showSnackBar(SnackBar(content: Text(invalidAmountText)));
                      return;
                    }

                    final locator = ServiceLocator();
                    final address = await locator.walletService.getAddress();
                    // Ưu tiên Ramp (backend/.env), sau đó Transak, cuối cùng BUY_URL
                    final baseUrl = locator.configService.rampBuyUrl ??
                        locator.configService.transakBuyUrl ??
                        dotenv.env['RAMP_BUY_URL'] ??
                        dotenv.env['TRANSAK_BUY_URL'] ??
                        dotenv.env['BUY_URL'] ??
                        'https://app.ramp.network/';
                    Uri uri;
                    try {
                      final parsed = Uri.parse(baseUrl);
                      final qp = Map<String, String>.from(parsed.queryParameters);
                      final lower = parsed.toString().toLowerCase();
                      final isTransak = lower.contains('transak');
                      final isRamp = lower.contains('ramp');

                      if (address.isNotEmpty) {
                        if (isTransak) {
                          qp.putIfAbsent('walletAddress', () => address);
                        } else if (isRamp) {
                          qp.putIfAbsent('userAddress', () => address);
                        }
                      }

                      // Prefill USDT và fiat params theo nhà cung cấp
                      if (isTransak) {
                        qp.putIfAbsent('cryptoCurrencyCode', () => 'USDT');
                        qp.putIfAbsent('network', () => 'bsc');
                        if (fiatCurrency.isNotEmpty) qp['fiatCurrency'] = fiatCurrency;
                        if (amount > 0) qp['defaultFiatAmount'] = amount.toString();
                      } else if (isRamp) {
                        // BSC USDT trên Ramp
                        qp.putIfAbsent('swapAsset', () => 'BSC_USDT');
                        if (fiatCurrency.isNotEmpty) qp['fiatCurrency'] = fiatCurrency;
                        if (amount > 0) qp['fiatValue'] = amount.toString();
                      } else {
                        // Tham số chung (nếu provider hỗ trợ)
                        qp.putIfAbsent('cryptoCurrencyCode', () => 'USDT');
                        if (fiatCurrency.isNotEmpty) qp['fiatCurrency'] = fiatCurrency;
                        if (amount > 0) qp['fiatAmount'] = amount.toString();
                      }

                      uri = parsed.replace(queryParameters: qp.isEmpty ? null : qp);
                    } catch (_) {
                      uri = Uri.parse('https://app.ramp.network/');
                    }
                    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!ok) {
                      messenger.showSnackBar(SnackBar(content: Text(openProviderText)));
                    }
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text("$openFailedPrefix: $e")));
                  }
                },
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: Text(AppI18n.tr(context, 'summary.deposit_usdt')),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Coin label (no button here)
          Text(
            AppI18n.tr(context, 'summary.coin'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.left,
          ),
          // Amount row with Refresh button on the right
          Row(
            children: [
              Expanded(
                child: Text(
                  '\$${AppFormat.formatUsdt(nonStableValue)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  // Pre-translate to avoid using BuildContext after await
                  final refreshingText = AppI18n.tr(context, 'summary.refreshing');
                  final refreshedText = AppI18n.tr(context, 'summary.refreshed');
                  final refreshFailedText = AppI18n.tr(context, 'summary.refresh_failed');
                  messenger.showSnackBar(SnackBar(content: Text(refreshingText)));
                  try {
                    await ServiceLocator().portfolioAdapter.refreshPortfolio();
                    messenger.showSnackBar(SnackBar(content: Text(refreshedText)));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$refreshFailedText: $e')));
                  }
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(AppI18n.tr(context, 'summary.refresh')),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

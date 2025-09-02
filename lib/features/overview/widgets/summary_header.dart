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
                  try {
                    final locator = ServiceLocator();
                    final address = await locator.walletService.getAddress();
                    // Ưu tiên URL từ backend qua ConfigService, fallback .env
                    final cfgUrl = locator.configService.transakBuyUrl;
                    final baseUrl = cfgUrl ?? dotenv.env['TRANSAK_BUY_URL'] ?? dotenv.env['BUY_URL'] ?? 'https://global.transak.com';
                    Uri uri;
                    try {
                      final parsed = Uri.parse(baseUrl);
                      final qp = Map<String, String>.from(parsed.queryParameters);
                      // Tự động gắn walletAddress nếu là Transak và chưa có sẵn.
                      if ((parsed.host.contains('transak') || parsed.toString().contains('transak')) && address.isNotEmpty) {
                        qp.putIfAbsent('walletAddress', () => address);
                      }
                      uri = parsed.replace(queryParameters: qp.isEmpty ? null : qp);
                    } catch (_) {
                      uri = Uri.parse('https://global.transak.com');
                    }
                    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!ok) {
                      messenger.showSnackBar(const SnackBar(content: Text('Không thể mở Transak')));
                    }
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Không thể mở nạp USDT: $e')));
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

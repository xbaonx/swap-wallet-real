import 'package:flutter/material.dart';
import '../../../core/i18n.dart';

import '../../../core/format.dart';
import '../../../domain/models/portfolio.dart';
import '../../../core/service_locator.dart';
import '../../portfolio/wert_deposit_screen.dart';

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
                    // Có thể truyền số tiền fiat mặc định nếu muốn, ví dụ 100 USD
                    final sessionId = await locator.wertService.createSession(walletAddress: address);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WertDepositScreen(sessionId: sessionId),
                        fullscreenDialog: true,
                      ),
                    );
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
                  messenger.showSnackBar(SnackBar(content: Text(AppI18n.tr(context, 'summary.refreshing'))));
                  try {
                    await ServiceLocator().portfolioAdapter.refreshPortfolio();
                    messenger.showSnackBar(SnackBar(content: Text(AppI18n.tr(context, 'summary.refreshed'))));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('${AppI18n.tr(context, 'summary.refresh_failed')}: $e')));
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

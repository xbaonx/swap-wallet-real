import 'package:flutter/material.dart';
import '../../../core/colors.dart';
import '../../../core/format.dart';
import '../../../core/i18n.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/coin.dart';
import '../../../domain/models/position.dart';
import '../../../storage/prefs_store.dart';
import '../../shared/coin_logo.dart';
import '../../trade/widgets/sell_sheet.dart';

class HoldingItem extends StatelessWidget {
  final Coin coin;
  final Position position;
  final PortfolioEngine portfolioEngine;
  final PrefsStore prefsStore;
  final bool isExpanded;
  final VoidCallback onTap;

  const HoldingItem({
    super.key,
    required this.coin,
    required this.position,
    required this.portfolioEngine,
    required this.prefsStore,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = position.qty * coin.last;
    final unrealizedPnL = (coin.last - position.avgEntry) * position.qty;
    final unrealizedPnLPercent = position.avgEntry > 0 
        ? ((coin.last - position.avgEntry) / position.avgEntry) * 100 
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              showSellSheet(
                context: context,
                base: coin.base,
                bid: coin.last,
                position: position,
                engine: portfolioEngine,
                prefsStore: prefsStore,
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header row: logo + base, last price, %24h, qty
                  Row(
                    children: [
                      CoinLogo(
                        base: coin.base,
                        size: 28,
                        radius: 6,
                        padding: const EdgeInsets.only(right: 12),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coin.base,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${AppI18n.tr(context, 'portfolio.holding.owned')} ${AppFormat.formatCoin(position.qty)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${AppFormat.formatUsdt(coin.last)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: coin.pct24h >= 0 ? AppColors.success : AppColors.danger,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              AppFormat.formatPercent(coin.pct24h),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Position details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppI18n.tr(context, 'portfolio.holding.avg_entry'),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '\$${AppFormat.formatUsdt(position.avgEntry)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              AppI18n.tr(context, 'portfolio.holding.value'),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '\$${AppFormat.formatUsdt(currentValue)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppI18n.tr(context, 'portfolio.holding.upnl'),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '\$${AppFormat.formatUsdt(unrealizedPnL)} (${AppFormat.formatPercent(unrealizedPnLPercent)})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: unrealizedPnL >= 0 ? AppColors.success : AppColors.danger,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

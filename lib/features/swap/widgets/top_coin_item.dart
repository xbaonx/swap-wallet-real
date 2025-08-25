import 'package:flutter/material.dart';
import '../../../core/colors.dart';
import '../../../core/format.dart';
import '../../../data/polling_service.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/coin.dart';
import '../../../domain/models/portfolio.dart';
import '../../../domain/models/position.dart';
import '../../../storage/prefs_store.dart';
import '../../overview/widgets/sparkline.dart';
import 'swap_inline_panel.dart';

class TopCoinItem extends StatelessWidget {
  final Coin coin;
  final Position? position;
  final Portfolio portfolio;
  final PortfolioEngine portfolioEngine;
  final PollingService pollingService;
  final PrefsStore prefsStore;
  final bool isExpanded;
  final VoidCallback onTap;

  const TopCoinItem({
    super.key,
    required this.coin,
    this.position,
    required this.portfolio,
    required this.portfolioEngine,
    required this.pollingService,
    required this.prefsStore,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPosition = position != null && position!.qty > 0;
    final unrealizedPnL = hasPosition 
        ? portfolioEngine.getUnrealizedPnL(coin.base, coin.last) 
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top row: emoji + base, last price, %24h, volume
                  Row(
                    children: [
                      Text(
                        coin.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
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
                              AppFormat.formatVolume(coin.quoteVolume),
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
                  
                  // Sparkline
                  SizedBox(
                    height: 60,
                    child: SparklineWidget(
                      coin: coin,
                      pollingService: pollingService,
                    ),
                  ),
                  
                  // Position info (if holding)
                  if (hasPosition) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sở hữu: ${AppFormat.formatCoin(position!.qty)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Giá trị: \$${AppFormat.formatUsdt(position!.qty * coin.last)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'U-P&L: \$${AppFormat.formatUsdt(unrealizedPnL)} (${AppFormat.formatPercent((unrealizedPnL / (position!.qty * position!.avgEntry)) * 100)})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: unrealizedPnL >= 0 ? AppColors.success : AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Expanded swap panel
          if (isExpanded)
            SwapInlinePanel(
              coin: coin,
              portfolio: portfolio,
              portfolioEngine: portfolioEngine,
              prefsStore: prefsStore,
            ),
        ],
      ),
    );
  }
}

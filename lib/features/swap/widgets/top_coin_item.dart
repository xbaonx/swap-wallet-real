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
import '../../shared/coin_logo.dart';
import '../../trade/widgets/swap_sheet.dart';

class TopCoinItem extends StatelessWidget {
  final Coin coin;
  final Position? position;
  final Portfolio portfolio;
  final PortfolioEngine portfolioEngine;
  final PollingService pollingService;
  final PrefsStore prefsStore;
  final int rank;
  final bool isExpanded;
  final VoidCallback? onTap;

  const TopCoinItem({
    super.key,
    required this.coin,
    this.position,
    required this.portfolio,
    required this.portfolioEngine,
    required this.pollingService,
    required this.prefsStore,
    required this.rank,
    required this.isExpanded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = coin.pct24h >= 0;
    final pctColor = isPositive ? AppColors.success : AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap ?? () {
          showSwapSheet(
            context: context,
            base: coin.base,
            ask: coin.last,
            usdtBalance: portfolio.usdt,
            engine: portfolioEngine,
            prefsStore: prefsStore,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              
              // Coin logo
              CoinLogo(
                base: coin.base,
                size: 28,
                radius: 6,
                padding: const EdgeInsets.only(right: 12),
              ),
              
              // Name + volume
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      coin.base,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${AppFormat.formatVolume(coin.quoteVolume)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${AppFormat.formatUsdt(coin.last)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              
              // Sparkline + % 24h
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32,
                      child: SparklineWidget(
                        coin: coin,
                        pollingService: pollingService,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          size: 16,
                          color: pctColor,
                        ),
                        Text(
                          AppFormat.formatPercent(coin.pct24h),
                          style: TextStyle(
                            color: pctColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

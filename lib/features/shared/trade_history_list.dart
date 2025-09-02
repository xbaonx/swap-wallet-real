import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/format.dart';
import '../../domain/models/trade.dart';

class TradeHistoryList extends StatelessWidget {
  final List<TradeRecord> trades;

  const TradeHistoryList({
    super.key,
    required this.trades,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (trades.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No trade history yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Trades',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trades.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              final trade = trades[index];
              final isBuy = trade.side == TradeSide.buy;
              final time = DateTime.fromMillisecondsSinceEpoch(trade.timestamp);
              
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Trade direction icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isBuy ? AppColors.success : AppColors.danger)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 16,
                        color: isBuy ? AppColors.success : AppColors.danger,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Trade info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${isBuy ? 'BUY' : 'SELL'} ${trade.base}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isBuy ? AppColors.success : AppColors.danger,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${AppFormat.formatCoin(trade.qty)} @ \$${AppFormat.formatUsdt(trade.price)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                ),
                              ),
                              
                              if (trade.realizedPnL != null) ...[
                                const Spacer(),
                                Text(
                                  'P&L ${trade.realizedPnL! >= 0 ? '+' : ''}${AppFormat.formatUsdt(trade.realizedPnL!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: trade.realizedPnL! >= 0 
                                        ? AppColors.success 
                                        : AppColors.danger,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

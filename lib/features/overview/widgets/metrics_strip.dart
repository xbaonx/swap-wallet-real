import 'package:flutter/material.dart';
import '../../../core/colors.dart';
import '../../../core/format.dart';
import '../../../domain/models/portfolio.dart';

class MetricsStrip extends StatelessWidget {
  final Portfolio portfolio;
  final Map<String, double> currentPrices;

  const MetricsStrip({
    super.key,
    required this.portfolio,
    required this.currentPrices,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coinValue = portfolio.calculateTotalCoinValue(currentPrices);
    final unrealized = portfolio.calculateTotalUnrealized(currentPrices);
    final netReturn = portfolio.calculateNetReturnPercent(currentPrices);
    
    // Metrics calculated successfully

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              title: 'Coin Value',
              value: '\$${AppFormat.formatUsdt(coinValue)}',
              theme: theme,
            ),
          ),
          Expanded(
            child: _MetricItem(
              title: 'Realized',
              value: '\$${AppFormat.formatUsdt(portfolio.realized)}',
              valueColor: portfolio.realized >= 0 ? AppColors.success : AppColors.danger,
              theme: theme,
            ),
          ),
          Expanded(
            child: _MetricItem(
              title: 'Unrealized',
              value: '\$${AppFormat.formatUsdt(unrealized)}',
              valueColor: unrealized >= 0 ? AppColors.success : AppColors.danger,
              theme: theme,
            ),
          ),
          Expanded(
            child: _MetricItem(
              title: 'Net Return',
              value: '${AppFormat.formatPercent(netReturn)}',
              valueColor: netReturn >= 0 ? AppColors.success : AppColors.danger,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;
  final ThemeData theme;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

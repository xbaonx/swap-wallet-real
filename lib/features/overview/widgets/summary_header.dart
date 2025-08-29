import 'package:flutter/material.dart';
 
import '../../../core/format.dart';
import '../../../domain/models/portfolio.dart';

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
          // USD (Stable) on top
          Text(
            'USD (Stable)',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.left,
          ),
          Text(
            '\$${AppFormat.formatUsdt(stableValue)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 8),
          // Coin value on next line
          Text(
            'Coin',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.left,
          ),
          Text(
            '\$${AppFormat.formatUsdt(nonStableValue)}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

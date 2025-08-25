import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/colors.dart';
import '../../../core/format.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/portfolio.dart';
import '../../../storage/prefs_store.dart';

class SummaryHeader extends StatelessWidget {
  final Portfolio portfolio;
  final Map<String, double> currentPrices;
  final PrefsStore prefsStore;
  final PortfolioEngine portfolioEngine;

  const SummaryHeader({
    super.key,
    required this.portfolio,
    required this.currentPrices,
    required this.prefsStore,
    required this.portfolioEngine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equity = portfolio.calculateEquity(currentPrices);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'USDT Balance',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '\$${AppFormat.formatUsdt(portfolio.usdt)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showAddUsdtDialog(context),
                    icon: const Icon(Icons.add_circle),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: prefsStore.themeMode,
                    builder: (context, themeMode, _) {
                      return PopupMenuButton<ThemeMode>(
                        initialValue: themeMode,
                        onSelected: prefsStore.setThemeMode,
                        icon: const Icon(Icons.brightness_6),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: ThemeMode.system,
                            child: Text('System'),
                          ),
                          const PopupMenuItem(
                            value: ThemeMode.light,
                            child: Text('Light'),
                          ),
                          const PopupMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Dark'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Equity',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '\$${AppFormat.formatUsdt(equity)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddUsdtDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add USDT'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '\$ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                portfolioEngine.addDeposit(amount);
                // Force persist ngay sau nạp USDT
                await prefsStore.commitNow(portfolioEngine.currentPortfolio);
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added \$${AppFormat.formatUsdt(amount)} USDT'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

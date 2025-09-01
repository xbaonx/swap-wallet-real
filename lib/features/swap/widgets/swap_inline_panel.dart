import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/colors.dart';
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../core/i18n.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/coin.dart';
import '../../../domain/models/portfolio.dart';
import '../../../domain/models/trade.dart';
import '../../../storage/prefs_store.dart';

class SwapInlinePanel extends StatefulWidget {
  final Coin coin;
  final Portfolio portfolio;
  final PortfolioEngine portfolioEngine;
  final PrefsStore prefsStore;

  const SwapInlinePanel({
    super.key,
    required this.coin,
    required this.portfolio,
    required this.portfolioEngine,
    required this.prefsStore,
  });

  @override
  State<SwapInlinePanel> createState() => _SwapInlinePanelState();
}

class _SwapInlinePanelState extends State<SwapInlinePanel> {
  final TextEditingController _controller = TextEditingController();
  bool _isBuying = true; // true: USDT->COIN, false: COIN->USDT
  double _inputAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final value = double.tryParse(_controller.text) ?? 0.0;
    setState(() => _inputAmount = value);
  }

  void _toggleDirection() {
    setState(() {
      _isBuying = !_isBuying;
      _controller.clear();
      _inputAmount = 0.0;
    });
  }

  void _setQuickPercentage(int percentage) {
    double amount;
    if (_isBuying) {
      amount = (widget.portfolio.usdt * percentage / 100);
    } else {
      final position = widget.portfolio.positions[widget.coin.base];
      amount = ((position?.qty ?? 0.0) * percentage / 100);
    }
    
    _controller.text = amount.toStringAsFixed(_isBuying ? 2 : 6);
    _onInputChanged();
  }

  bool get _canExecute {
    if (_inputAmount <= 0) return false;
    
    if (_isBuying) {
      return widget.portfolio.usdt >= _inputAmount;
    } else {
      final position = widget.portfolio.positions[widget.coin.base];
      return position != null && position.qty >= _inputAmount;
    }
  }

  String get _estimatedOutput {
    if (_inputAmount <= 0) return '';
    
    if (_isBuying) {
      final coinRecv = (_inputAmount / widget.coin.ask) * (1 - AppConstants.tradingFee);
      return '${AppI18n.tr(context, 'trade.estimate.receive_prefix')} ${AppFormat.formatCoin(coinRecv)} ${widget.coin.base} ${AppI18n.tr(context, 'trade.estimate.after_fee')}';
    } else {
      final usdtOut = (_inputAmount * widget.coin.bid) * (1 - AppConstants.tradingFee);
      return '${AppI18n.tr(context, 'trade.estimate.receive_prefix')} ${AppFormat.formatUsdt(usdtOut)} USDT ${AppI18n.tr(context, 'trade.estimate.after_fee')}';
    }
  }

  void _executeSwap() async {
    if (!_canExecute) return;

    if (_isBuying) {
      final result = widget.portfolioEngine.buyOrder(widget.coin.base, _inputAmount, widget.coin.ask);
      
      if (result.ok) {
        await widget.prefsStore.recordBuy(
          base: result.base,
          qty: result.qty,
          price: result.price,
          feeRate: result.feeRate,
          usdtIn: result.usdt,
        );
        // Force persist ngay
        await widget.prefsStore.commitNow(widget.portfolioEngine.currentPortfolio);
      }
      
      HapticFeedback.lightImpact();
      
      final message = result.ok 
          ? '${AppI18n.tr(context, 'trade.snackbar.bought_prefix')} ${result.base} ${AppI18n.tr(context, 'trade.snackbar.for')} ${AppFormat.formatUsdt(result.usdt)} USDT'
          : AppI18n.tr(context, 'trade.snackbar.buy_failed');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final result = widget.portfolioEngine.sellOrder(widget.coin.base, _inputAmount, widget.coin.bid);
      
      if (result.ok) {
        await widget.prefsStore.recordSell(
          base: result.base,
          qty: result.qty,
          price: result.price,
          feeRate: result.feeRate,
          usdtOut: result.usdt,
          realizedPnL: result.realized ?? 0.0,
        );
        // Force persist ngay
        await widget.prefsStore.commitNow(widget.portfolioEngine.currentPortfolio);
      }
      
      HapticFeedback.lightImpact();
      
      final message = result.ok 
          ? '${AppI18n.tr(context, 'trade.snackbar.sold_prefix')} ${AppFormat.formatCoin(result.qty)} ${result.base}'
          : AppI18n.tr(context, 'trade.snackbar.sell_failed');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _controller.clear();
    setState(() => _inputAmount = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark 
            ? AppColors.darkSurfaceAlt 
            : AppColors.lightSurfaceAlt,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Column(
        children: [
          // Direction toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isBuying ? 'USDT' : widget.coin.base,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _toggleDirection,
                icon: const Icon(Icons.swap_horiz, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              Text(
                _isBuying ? widget.coin.base : 'USDT',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Input field
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _isBuying ? AppI18n.tr(context, 'trade.input.amount_usdt') : AppI18n.tr(context, 'trade.input.amount_coin'),
              prefixText: _isBuying ? '\$ ' : '',
              suffixText: _isBuying ? 'USDT' : widget.coin.base,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: theme.textTheme.headlineSmall,
          ),
          
          const SizedBox(height: 16),
          
          // Quick percentage buttons
          Row(
            children: AppConstants.quickPercentages.map((percentage) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: percentage != AppConstants.quickPercentages.last ? 8 : 0,
                  ),
                  child: OutlinedButton(
                    onPressed: () => _setQuickPercentage(percentage),
                    child: Text(percentage == 100 ? AppI18n.tr(context, 'trade.quick.max') : '$percentage%'),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Fee info
          Text(
            '${AppI18n.tr(context, 'trade.fee_info.buy_using_ask')}, ${AppI18n.tr(context, 'trade.fee_info.sell_using_bid')} • ${AppI18n.tr(context, 'trade.fee')} ${(AppConstants.tradingFee * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          // Estimated output
          if (_estimatedOutput.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _estimatedOutput,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Execute button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canExecute ? _executeSwap : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isBuying ? AppColors.success : AppColors.danger,
              ),
              child: Text(
                _isBuying ? '${AppI18n.tr(context, 'trade.buy')} ${widget.coin.base}' : '${AppI18n.tr(context, 'trade.sell')} ${widget.coin.base}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

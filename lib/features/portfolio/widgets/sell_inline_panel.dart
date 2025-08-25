import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/colors.dart';
import '../../../core/constants.dart';
import '../../../core/format.dart';
import '../../../domain/logic/portfolio_engine.dart';
import '../../../domain/models/coin.dart';
import '../../../domain/models/portfolio.dart';
import '../../../domain/models/position.dart';
import '../../../domain/models/trade.dart';
import '../../../storage/prefs_store.dart';

class SellInlinePanel extends StatefulWidget {
  final Coin coin;
  final Position position;
  final PortfolioEngine portfolioEngine;
  final PrefsStore prefsStore;

  const SellInlinePanel({
    super.key,
    required this.coin,
    required this.position,
    required this.portfolioEngine,
    required this.prefsStore,
  });

  @override
  State<SellInlinePanel> createState() => _SellInlinePanelState();
}

class _SellInlinePanelState extends State<SellInlinePanel> {
  final TextEditingController _controller = TextEditingController();
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

  void _setQuickPercentage(int percentage) {
    final amount = (widget.position.qty * percentage / 100);
    _controller.text = amount.toStringAsFixed(6);
    _onInputChanged();
  }

  bool get _canExecute {
    return _inputAmount > 0 && _inputAmount <= widget.position.qty;
  }

  String get _estimatedOutput {
    if (_inputAmount <= 0) return '';
    
    final usdtOut = (_inputAmount * widget.coin.bid) * (1 - AppConstants.tradingFee);
    return 'Nhận ~ \$${AppFormat.formatUsdt(usdtOut)} USDT (sau phí)';
  }

  void _executeSell() async {
    if (!_canExecute) return;

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
        ? 'Sold ${AppFormat.formatCoin(result.qty)} ${result.base} for \$${AppFormat.formatUsdt(result.usdt)}'
        : 'Sell order failed';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );

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
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sell,
                color: AppColors.danger,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Bán ${widget.coin.base}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Available quantity info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.brightness == Brightness.dark 
                    ? AppColors.darkBorder 
                    : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Khả dụng:',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '${AppFormat.formatCoin(widget.position.qty)} ${widget.coin.base}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Input field
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${widget.coin.base} Amount',
              suffixText: widget.coin.base,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _inputAmount > widget.position.qty 
                  ? 'Vượt quá số lượng khả dụng' 
                  : null,
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
                    child: Text(percentage == 100 ? 'Max' : '$percentage%'),
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Fee info
          Text(
            'Bán dùng bid • Phí ${(AppConstants.tradingFee * 100).toStringAsFixed(1)}%',
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
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _estimatedOutput,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.danger,
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
              onPressed: _canExecute ? _executeSell : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.danger,
              ),
              child: Text(
                'Bán ${widget.coin.base}',
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

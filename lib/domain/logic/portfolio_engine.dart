import 'dart:async';
import '../models/portfolio.dart';
import '../models/position.dart';
import '../../core/constants.dart';

class TradeExecResult {
  final bool ok;
  final String base;
  final double qty;        // BUY: qty coin nhận | SELL: qty coin bán
  final double price;      // ASK (buy) hoặc BID (sell) dùng để khớp
  final double usdt;       // BUY: usdtIn (số âm nếu muốn), SELL: usdtOut (dương)
  final double feeRate;    // AppConstants.tradingFee
  final double? realized;  // chỉ có ở SELL

  const TradeExecResult({
    required this.ok,
    required this.base,
    required this.qty,
    required this.price,
    required this.usdt,
    required this.feeRate,
    this.realized,
  });
}

class PortfolioEngine {
  final StreamController<Portfolio> _portfolioController = StreamController<Portfolio>.broadcast();
  Portfolio _portfolio = const Portfolio(
    usdt: AppConstants.initialUsdt,
    deposits: AppConstants.initialDeposits,
    realized: 0.0,
    positions: {},
  );

  Stream<Portfolio> get portfolioStream => _portfolioController.stream;
  Portfolio get currentPortfolio => _portfolio;

  void setPortfolio(Portfolio portfolio) {
    _portfolio = portfolio;
    _portfolioController.add(_portfolio);
  }

  TradeExecResult buyOrder(String base, double usdtIn, double askPrice) {
    if (usdtIn <= 0 || _portfolio.usdt < usdtIn) {
      return TradeExecResult(
        ok: false,
        base: base,
        qty: 0.0,
        price: askPrice,
        usdt: 0.0,
        feeRate: AppConstants.tradingFee,
        realized: null,
      );
    }

    final coinRecv = (usdtIn / askPrice) * (1 - AppConstants.tradingFee);
    final currentPosition = _portfolio.positions[base] ?? const Position(qty: 0.0, avgEntry: 0.0);

    final newQty = currentPosition.qty + coinRecv;
    final newCost = (currentPosition.qty * currentPosition.avgEntry) + usdtIn;
    final newAvgEntry = newCost / newQty;

    final updatedPositions = Map<String, Position>.from(_portfolio.positions);
    updatedPositions[base] = Position(qty: newQty, avgEntry: newAvgEntry);

    _portfolio = _portfolio.copyWith(
      usdt: _portfolio.usdt - usdtIn,
      positions: updatedPositions,
    );

    _portfolioController.add(_portfolio);

    return TradeExecResult(
      ok: true,
      base: base,
      qty: coinRecv,
      price: askPrice,
      usdt: usdtIn,
      feeRate: AppConstants.tradingFee,
      realized: null,
    );
  }

  TradeExecResult sellOrder(String base, double qtySell, double bidPrice) {
    final currentPosition = _portfolio.positions[base];
    if (qtySell <= 0 || currentPosition == null || currentPosition.qty < qtySell) {
      return TradeExecResult(
        ok: false,
        base: base,
        qty: 0.0,
        price: bidPrice,
        usdt: 0.0,
        feeRate: AppConstants.tradingFee,
        realized: 0.0,
      );
    }

    final usdtOut = (qtySell * bidPrice) * (1 - AppConstants.tradingFee);
    final realizedPnL = usdtOut - (qtySell * currentPosition.avgEntry);
    final newQty = currentPosition.qty - qtySell;

    final updatedPositions = Map<String, Position>.from(_portfolio.positions);
    if (newQty <= 0) {
      updatedPositions.remove(base);
    } else {
      updatedPositions[base] = currentPosition.copyWith(qty: newQty);
    }

    _portfolio = _portfolio.copyWith(
      usdt: _portfolio.usdt + usdtOut,
      realized: _portfolio.realized + realizedPnL,
      positions: updatedPositions,
    );

    _portfolioController.add(_portfolio);

    return TradeExecResult(
      ok: true,
      base: base,
      qty: qtySell,
      price: bidPrice,
      usdt: usdtOut,
      feeRate: AppConstants.tradingFee,
      realized: realizedPnL,
    );
  }

  void addDeposit(double amount) {
    if (amount <= 0) return;

    _portfolio = _portfolio.copyWith(
      usdt: _portfolio.usdt + amount,
      deposits: _portfolio.deposits + amount,
    );

    _portfolioController.add(_portfolio);
  }

  double getUnrealizedPnL(String base, double currentPrice) {
    final position = _portfolio.positions[base];
    if (position == null || position.qty == 0) return 0.0;
    return (currentPrice - position.avgEntry) * position.qty;
  }

  void dispose() {
    _portfolioController.close();
  }
}

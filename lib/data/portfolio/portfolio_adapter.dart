import 'dart:async';
import '../../domain/models/portfolio.dart';
import '../../domain/models/position.dart';
import '../../domain/logic/portfolio_engine.dart';
import '../../services/moralis_client.dart';
import '../../onchain/wallet/wallet_service.dart';
import '../../data/token/token_registry.dart';
import '../../core/constants.dart';

/// Adapter that replaces PortfolioEngine for data sources
/// Maintains identical API signatures while using Moralis balances + tokenPrice
class PortfolioAdapter extends PortfolioEngine {
  final MoralisClient _moralisClient;
  final WalletService _walletService;
  final TokenRegistry _tokenRegistry;
  
  
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  static const Duration _refreshInterval = Duration(seconds: 30);

  PortfolioAdapter({
    required MoralisClient moralisClient,
    required WalletService walletService,
    required TokenRegistry tokenRegistry,
  })  : _moralisClient = moralisClient,
        _walletService = walletService,
        _tokenRegistry = tokenRegistry,
        super();

  // Original PortfolioEngine API - EXACT 
  @override
  void setPortfolio(Portfolio portfolio) {
    super.setPortfolio(portfolio);
  }

  /// Sync with ground truth from Moralis - call this to override local state
  Future<void> syncWithBlockchain() async {
    if (!_walletService.isInitialized || _walletService.isLocked) {
      return; // Cannot sync without wallet
    }
    
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final address = await _walletService.getAddress();
      print('🔍 PORTFOLIO ADAPTER: Syncing portfolio for $address...');
      
      // Get token balances from Moralis
      final balancesResponse = await _moralisClient.walletTokenBalances(address: address);
      final tokenBalances = balancesResponse.result;
      
      // Get native BNB balance
      final bnbBalanceWei = await _moralisClient.getNativeBalance(address: address);
      final bnbBalance = BigInt.parse(bnbBalanceWei).toDouble() / 1e18;
      
      // Convert Moralis balances to positions
      final newPositions = <String, Position>{};
      double totalUsdtBalance = 0.0;
      
      for (final tokenBalance in tokenBalances) {
        // Skip spam tokens
        if (tokenBalance.possibleSpam == true) continue;
        
        final symbol = tokenBalance.symbol.toUpperCase();
        final balance = BigInt.parse(tokenBalance.balance).toDouble() / 
                       BigInt.from(10).pow(tokenBalance.decimals).toDouble();
        
        // Skip dust amounts
        if (balance < 1e-8) continue;
        
        try {
          // Get USD price for this token
          final priceData = await _moralisClient.tokenPrice(tokenAddress: tokenBalance.tokenAddress);
          final usdPrice = priceData.usdPrice;
          
          if (symbol == 'USDT' || symbol == 'BUSD' || symbol == 'USDC') {
            // These are stablecoin balances - add to USDT balance
            totalUsdtBalance += balance;
          } else {
            // Create position with current market price as avgEntry
            // This assumes user acquired tokens at current price (for P&L calculation)
            newPositions[symbol] = Position(
              qty: balance,
              avgEntry: usdPrice,
            );
          }
          
          print('🔍 PORTFOLIO SYNC: $symbol balance=$balance price=\$${usdPrice.toStringAsFixed(2)}');
        } catch (e) {
          print('🔍 PORTFOLIO SYNC: Failed to get price for ${tokenBalance.symbol}: $e');
          // Skip tokens without price data
        }
      }
      
      // Handle BNB balance
      if (bnbBalance > 1e-8) {
        try {
          final bnbPrice = await _moralisClient.getBnbPrice();
          newPositions['BNB'] = Position(
            qty: bnbBalance,
            avgEntry: bnbPrice,
          );
          print('🔍 PORTFOLIO SYNC: BNB balance=$bnbBalance price=\$${bnbPrice.toStringAsFixed(2)}');
        } catch (e) {
          print('🔍 PORTFOLIO SYNC: Failed to get BNB price: $e');
        }
      }
      
      // Create new portfolio with blockchain data, but preserve realized P&L and deposits
      final newPortfolio = currentPortfolio.copyWith(
        usdt: totalUsdtBalance,
        positions: newPositions,
        // Keep existing realized P&L and deposits from local state
      );
      
      setPortfolio(newPortfolio);
      
      print('🔍 PORTFOLIO SYNC: Updated portfolio - USDT: ${totalUsdtBalance.toStringAsFixed(2)}, Positions: ${newPositions.length}');
    } catch (e) {
      print('🔍 PORTFOLIO SYNC: Failed to sync portfolio: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Manual sync - call this after swaps or when user wants to refresh
  Future<void> refreshPortfolio() async {
    await syncWithBlockchain();
  }

  /// Legacy method - now does nothing (periodic sync disabled to save resources)
  void startPeriodicSync() {
    print('🔍 PORTFOLIO ADAPTER: Periodic sync disabled - use manual refresh instead');
  }

  void stopPeriodicSync() {
    _refreshTimer?.cancel();
  }

  // Original PortfolioEngine trading methods - PRESERVED FOR UI COMPATIBILITY
  // These will be called by SwapAdapter instead of directly manipulating portfolio
  @override
  TradeExecResult buyOrder(String base, double usdtIn, double askPrice) {
    if (usdtIn <= 0 || currentPortfolio.usdt < usdtIn - 0.01) {
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

    final coinRecv = (usdtIn * (1 - AppConstants.tradingFee)) / askPrice;
    final currentPosition = currentPortfolio.positions[base];

    final updatedPositions = Map<String, Position>.from(currentPortfolio.positions);

    final newQty = (currentPosition?.qty ?? 0.0) + coinRecv;
    final newCost = ((currentPosition?.qty ?? 0.0) * (currentPosition?.avgEntry ?? askPrice)) + usdtIn;
    final newAvgEntry = newCost / newQty;

    updatedPositions[base] = Position(qty: newQty, avgEntry: newAvgEntry);

    setPortfolio(currentPortfolio.copyWith(
      usdt: currentPortfolio.usdt - usdtIn,
      positions: updatedPositions,
    ));

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

  @override
  TradeExecResult sellOrder(String base, double qtySell, double bidPrice) {
    final currentPosition = currentPortfolio.positions[base];
    if (qtySell <= 0 || currentPosition == null || currentPosition.qty < qtySell - 1e-6) {
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

    final updatedPositions = Map<String, Position>.from(currentPortfolio.positions);
    if (newQty <= 1e-8) {
      updatedPositions.remove(base);
    } else {
      updatedPositions[base] = currentPosition.copyWith(qty: newQty);
    }

    setPortfolio(currentPortfolio.copyWith(
      usdt: currentPortfolio.usdt + usdtOut,
      realized: currentPortfolio.realized + realizedPnL,
      positions: updatedPositions,
    ));

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

    setPortfolio(currentPortfolio.copyWith(
      usdt: currentPortfolio.usdt + amount,
      deposits: currentPortfolio.deposits + amount,
    ));
  }

  @override
  double getUnrealizedPnL(String base, double currentPrice) {
    final position = currentPortfolio.positions[base];
    if (position == null || position.qty == 0) return 0.0;
    return (currentPrice - position.avgEntry) * position.qty;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

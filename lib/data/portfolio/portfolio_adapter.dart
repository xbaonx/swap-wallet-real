import 'dart:async';
import 'dart:developer' as developer;
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
  

  PortfolioAdapter({
    required MoralisClient moralisClient,
    required WalletService walletService,
    required TokenRegistry tokenRegistry,
  })  : _moralisClient = moralisClient,
        _walletService = walletService,
        _tokenRegistry = tokenRegistry,
        super();

  // Original PortfolioEngine API - use inherited implementation directly

  /// Sync with ground truth from Moralis - call this to override local state
  Future<void> syncWithBlockchain({List<String>? chains}) async {
    // Basic guards
    if (!_walletService.isInitialized || _walletService.isLocked) {
      developer.log('Sync aborted - wallet not ready (initialized=${_walletService.isInitialized}, locked=${_walletService.isLocked})', name: 'portfolio');
      return; // Cannot sync without wallet
    }
    
    if (_isRefreshing) {
      developer.log('Sync skipped - already refreshing', name: 'portfolio');
      return;
    }
    _isRefreshing = true;

    try {
      final address = await _walletService.getAddress();
      final masked = address.length > 10
          ? '${address.substring(0, 6)}...${address.substring(address.length - 4)}'
          : address;
      developer.log('Sync start for $masked', name: 'portfolio');
      // Default chains to aggregate
      final targetChains = chains ?? const ['bsc', 'eth', 'polygon'];
      const nativeSymbols = {
        'bsc': 'BNB',
        'eth': 'ETH',
        'polygon': 'MATIC',
      };

      // Aggregate positions across chains
      final newPositions = <String, Position>{};
      
      for (final chain in targetChains) {
        // 1) ERC20 balances per chain
        final balancesResponse = await _moralisClient.walletTokenBalances(address: address, chain: chain);
        final tokenBalances = balancesResponse.result;
        developer.log('[CHAIN:$chain] Moralis returned ${tokenBalances.length} token balances', name: 'portfolio');

        for (final tokenBalance in tokenBalances) {
          // Skip spam tokens
          if (tokenBalance.possibleSpam == true) continue;

          final symbol = tokenBalance.symbol.toUpperCase();
          // Canonicalize symbol using TokenRegistry by address when available
          final canonicalSymbol = _tokenRegistry
                  .getByAddress(tokenBalance.tokenAddress)
                  ?.symbol
                  .toUpperCase() ??
              symbol;
          final balance = BigInt.parse(tokenBalance.balance).toDouble() /
              BigInt.from(10).pow(tokenBalance.decimals).toDouble();

          // Skip dust amounts
          if (balance < 1e-8) continue;

          try {
            // Get USD price for this token (on its chain)
            final priceData = await _moralisClient.tokenPrice(
              tokenAddress: tokenBalance.tokenAddress,
              chain: chain,
            );
            final usdPrice = priceData.usdPrice;

            // Aggregate tất cả token (bao gồm stablecoins) như holdings riêng
            final existing = newPositions[canonicalSymbol];
            if (existing == null) {
              newPositions[canonicalSymbol] = Position(qty: balance, avgEntry: usdPrice);
            } else {
              newPositions[canonicalSymbol] = Position(
                qty: existing.qty + balance,
                // keep previous avgEntry (giá vốn tạm bằng giá hiện tại lần đầu thấy)
                avgEntry: existing.avgEntry,
              );
            }
          } catch (e) {
            // Skip tokens without price data
          }
        }

        // 2) Native balance per chain
        try {
          final nativeBalWei = await _moralisClient.getNativeBalance(address: address, chain: chain);
          final nativeBal = BigInt.parse(nativeBalWei).toDouble() / 1e18;
          if (nativeBal > 1e-8) {
            final nativePrice = await _moralisClient.getNativePrice(chain: chain);
            final symbol = nativeSymbols[chain] ?? chain.toUpperCase();
            final existing = newPositions[symbol];
            if (existing == null) {
              newPositions[symbol] = Position(qty: nativeBal, avgEntry: nativePrice);
            } else {
              newPositions[symbol] = Position(
                qty: existing.qty + nativeBal,
                avgEntry: existing.avgEntry,
              );
            }
          }
        } catch (e) {
          // ignore native errors per chain
        }
      }
      
      // Create new portfolio with blockchain data
      // Lựa chọn 2: Stablecoins hiển thị như holdings riêng => KHÔNG override usdt.
      // One-time migration: nếu usdt hiện tại ~ tổng stable qty (USDT/USDC/BUSD), đặt usdt=0 để tránh double count.
      // Lý do: các phiên bản trước chỉ gộp 3 stable này vào usdt.
      final stableSymbols = {'USDT', 'USDC', 'BUSD'};
      final approxStableQty = newPositions.entries
          .where((e) => stableSymbols.contains(e.key))
          .fold<double>(0.0, (sum, e) => sum + e.value.qty);

      double? migratedUsdt;
      if (currentPortfolio.usdt > 0 && approxStableQty > 0) {
        final diff = (currentPortfolio.usdt - approxStableQty).abs();
        final tolerance = 0.05 + 0.005 * approxStableQty; // 5 cents + 0.5%
        if (diff <= tolerance) {
          migratedUsdt = 0.0;
        }
      }

      final newPortfolio = currentPortfolio.copyWith(
        usdt: migratedUsdt,
        positions: newPositions,
        // Keep realized P&L and deposits from local state
      );
      
      setPortfolio(newPortfolio);
      developer.log('Sync complete | positions=${newPositions.length}, usdt=${newPortfolio.usdt.toStringAsFixed(4)}', name: 'portfolio');
      
    } catch (e) {
      // Failed to sync portfolio
      developer.log('Sync failed -> $e', name: 'portfolio');
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
    // Periodic sync disabled to save resources
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

  @override
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

  /// Get current wallet address for UI display
  Future<String?> getCurrentWalletAddress() async {
    try {
      if (!_walletService.isInitialized || _walletService.isLocked) {
        return null;
      }
      return await _walletService.getAddress();
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

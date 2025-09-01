import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:convert/convert.dart';
import '../wallet/wallet_service.dart';
import '../rpc/rpc_client.dart';
import '../../services/inch_client.dart';
import '../../data/token/token_registry.dart';
import '../../data/portfolio/portfolio_adapter.dart';
import '../../domain/logic/portfolio_engine.dart';
import '../../core/errors.dart';
import '../../core/constants.dart';

enum SwapStatus { pending, confirmed, failed }

class SwapResult {
  final bool success;
  final String? txHash;
  final String? error;
  final AppErrorCode? errorCode;

  const SwapResult({
    required this.success,
    this.txHash,
    this.error,
    this.errorCode,
  });

  factory SwapResult.success(String txHash) => SwapResult(
    success: true,
    txHash: txHash,
  );

  factory SwapResult.failure(String error, [AppErrorCode? code]) => SwapResult(
    success: false,
    error: error,
    errorCode: code,
  );
}

class SwapWatcher {
  final String txHash;
  final StreamController<SwapStatus> _statusController = StreamController<SwapStatus>.broadcast();
  final IRpcClient _rpcClient;
  Timer? _pollTimer;

  SwapWatcher({
    required this.txHash,
    required IRpcClient rpcClient,
  }) : _rpcClient = rpcClient;

  Stream<SwapStatus> get statusStream => _statusController.stream;

  void startWatching() {
    _statusController.add(SwapStatus.pending);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final receipt = await _rpcClient.getReceipt(txHash);
      if (receipt != null) {
        _pollTimer?.cancel();
        final status = receipt.status == true ? SwapStatus.confirmed : SwapStatus.failed;
        _statusController.add(status);
        _statusController.close();
      }
    } catch (e) {
      // Continue polling on error
      dev.log('SwapWatcher: Error checking status: $e');
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _statusController.close();
  }
}

class SwapAdapter {
  final InchClient _inchClient;
  final WalletService _walletService;
  final IRpcClient _rpcClient;
  final TokenRegistry _tokenRegistry;
  final PortfolioAdapter _portfolioAdapter;
  
  final Map<String, SwapWatcher> _activeWatchers = {};
  
  static const int _bscChainId = 56;
  static final BigInt _maxApproveAmount = BigInt.parse('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');

  SwapAdapter({
    required InchClient inchClient,
    required WalletService walletService,
    required IRpcClient rpcClient,
    required TokenRegistry tokenRegistry,
    required PortfolioAdapter portfolioAdapter,
  })  : _inchClient = inchClient,
        _walletService = walletService,
        _rpcClient = rpcClient,
        _tokenRegistry = tokenRegistry,
        _portfolioAdapter = portfolioAdapter;

  /// Execute swap - maintains same signature as original trade executor
  Future<TradeExecResult> executeSwap({
    required String fromSymbol,
    required String toSymbol, 
    required double amount,
    double slippageBps = 50, // 0.5% default
  }) async {
    try {
      if (!_walletService.isInitialized || _walletService.isLocked) {
        throw AppError.walletLocked();
      }

      final fromAddress = _tokenRegistry.getTokenAddress(fromSymbol);
      final toAddress = _tokenRegistry.getTokenAddress(toSymbol);
      final walletAddress = await _walletService.getAddress();
      
      if (fromAddress == null || toAddress == null) {
        throw AppError(
          code: AppErrorCode.unknown,
          message: 'Token address not found for $fromSymbol or $toSymbol',
        );
      }

      // Convert amount to wei
      final fromDecimals = _tokenRegistry.getTokenDecimals(fromSymbol);
      final amountWei = _convertToWei(amount, fromDecimals);
      
      // Strict on-chain balance check to avoid 1inch HTTP 400 for over-amount
      BigInt balanceWei;
      final isNative = _isNativeToken(fromAddress);
      if (isNative) {
        balanceWei = await _rpcClient.getBalance(walletAddress);
      } else {
        balanceWei = await _rpcClient.getTokenBalance(walletAddress, fromAddress);
      }
      // For ERC-20: allow using full token balance. For native: keep tiny 1-wei margin.
      final allowedMax = isNative
          ? (balanceWei > BigInt.zero ? balanceWei - BigInt.one : BigInt.zero)
          : balanceWei;
      if (amountWei > allowedMax) {
        final available = _convertFromWei(balanceWei, fromDecimals);
        throw AppError.networkError('Insufficient $fromSymbol balance. Required: $amount, Available: ${available.toStringAsFixed(8)}');
      }
      
      // Check if approval is needed (skip for native BNB)
      if (!_isNativeToken(fromAddress)) {
        final hasAllowance = await _checkAndApprove(
          tokenAddress: fromAddress,
          walletAddress: walletAddress,
          amountWei: amountWei.toString(),
        );
        
        if (!hasAllowance) {
          // Should not happen with current _checkAndApprove implementation,
          // but enforce explicit error to surface to UI if it ever does.
          throw AppError.allowanceRequired(fromSymbol, 'DEX Router');
        }
      }

      // Build swap transaction with referral fee
      final swapResponse = await _inchClient.buildSwapTx(
        fromTokenAddress: fromAddress,
        toTokenAddress: toAddress,
        amountWei: amountWei.toString(),
        fromAddress: walletAddress,
        slippageBps: slippageBps.round(),
        referrerAddress: AppConstants.referrerAddress,
        referrerFeePercent: AppConstants.referrerFeePercent,
      );

      // Create transaction (estimate gas/gasPrice if 1inch returned 0)
      final swapFrom = EthereumAddress.fromHex(swapResponse.tx.from);
      final swapTo = EthereumAddress.fromHex(swapResponse.tx.to);
      final swapData = Uint8List.fromList(hex.decode(swapResponse.tx.data.substring(2)));
      final swapValue = EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(swapResponse.tx.value));

      BigInt swapGasPriceWei = BigInt.tryParse(swapResponse.tx.gasPrice) ?? BigInt.zero;
      if (swapGasPriceWei == BigInt.zero) {
        final gp = await _rpcClient.getGasPrice();
        swapGasPriceWei = gp.getInWei;
      }
      int swapGasLimit = int.tryParse(swapResponse.tx.gas) ?? 0;
      if (swapGasLimit == 0) {
        final est = await _rpcClient.estimateGas(Transaction(
          from: swapFrom,
          to: swapTo,
          value: swapValue,
          data: swapData,
        ));
        final estInt = est.toInt();
        swapGasLimit = (estInt + (estInt * 2 ~/ 10)).clamp(21000, 2000000);
      }

      final transaction = Transaction(
        from: swapFrom,
        to: swapTo,
        data: swapData,
        value: swapValue,
        gasPrice: EtherAmount.fromBigInt(EtherUnit.wei, swapGasPriceWei),
        maxGas: swapGasLimit,
      );

      // Sign and send transaction
      final signedTx = await _walletService.signRawTx(transaction, chainId: _bscChainId);
      final txHash = await _rpcClient.sendRawTransaction('0x$signedTx');

      // Calculate output amounts (amount of toToken received)
      final toDecimals = _tokenRegistry.getTokenDecimals(toSymbol);
      final outputAmount = _convertFromWei(BigInt.parse(swapResponse.toTokenAmount), toDecimals);

      // Determine base (coin symbol), qty (coin amount), usdt amount, and price (USDT per coin)
      final isBuy = fromSymbol == 'USDT';
      final baseSymbol = isBuy ? toSymbol : fromSymbol; // Always the coin symbol
      final coinQty = isBuy ? outputAmount : amount; // BUY: coin received, SELL: coin sold
      final usdtAmount = (toSymbol == 'USDT') ? outputAmount : amount; // BUY: usdt in, SELL: usdt out
      final priceUsdtPerCoin = (toSymbol == 'USDT')
          ? (amount > 0 ? (outputAmount / amount) : 0.0) // SELL: USDT out per coin sold
          : (outputAmount > 0 ? (amount / outputAmount) : 0.0); // BUY: USDT in per coin received

      dev.log('🔍 SWAP ADAPTER: Executed swap $fromSymbol->$toSymbol, tx: $txHash');

      // Sync portfolio after successful swap to reflect new balances
      Future.delayed(const Duration(seconds: 10), () {
        _portfolioAdapter.refreshPortfolio();
        dev.log('🔍 SWAP ADAPTER: Portfolio synced after swap completion');
      });

      return TradeExecResult(
        ok: true,
        base: baseSymbol,
        qty: coinQty,
        price: priceUsdtPerCoin,
        usdt: usdtAmount,
        feeRate: AppConstants.tradingFee,
        realized: null,
      );
    } catch (e) {
      dev.log('🔍 SWAP ADAPTER: Swap failed: $e');
      if (e is AppError) {
        rethrow; // propagate specific error to UI
      }
      throw AppError.unknown(e);
    }
  }

  Future<bool> _checkAndApprove({
    required String tokenAddress,
    required String walletAddress,
    required String amountWei,
  }) async {
    try {
      // Get spender address
      final spender = await _inchClient.spender();
      
      // Check current allowance
      final allowanceResponse = await _inchClient.allowance(
        tokenAddress: tokenAddress,
        walletAddress: walletAddress,
        spenderAddress: spender,
      );
      
      final currentAllowance = BigInt.parse(allowanceResponse.allowance);
      final requiredAmount = BigInt.parse(amountWei);
      
      if (currentAllowance >= requiredAmount) {
        return true; // Sufficient allowance
      }
      
      // Build approve transaction
      final approveTx = await _inchClient.buildApproveTx(
        tokenAddress: tokenAddress,
        amountWei: _maxApproveAmount.toString(), // Max approval
        fromAddress: walletAddress,
        spenderAddress: spender,
      );
      
      // Prepare approve transaction values and estimate if needed
      final approveFrom = EthereumAddress.fromHex(approveTx.from);
      final approveTo = EthereumAddress.fromHex(approveTx.to);
      final approveData = Uint8List.fromList(hex.decode(approveTx.data.substring(2)));
      final approveValue = EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(approveTx.value));

      BigInt approveGasPriceWei = BigInt.tryParse(approveTx.gasPrice) ?? BigInt.zero;
      if (approveGasPriceWei == BigInt.zero) {
        final gp = await _rpcClient.getGasPrice();
        approveGasPriceWei = gp.getInWei;
      }
      int approveGasLimit = int.tryParse(approveTx.gas) ?? 0;
      if (approveGasLimit == 0) {
        final est = await _rpcClient.estimateGas(Transaction(
          from: approveFrom,
          to: approveTo,
          value: approveValue,
          data: approveData,
        ));
        // add 20% buffer
        final estInt = est.toInt();
        approveGasLimit = (estInt + (estInt * 2 ~/ 10)).clamp(21000, 150000);
      }

      // Create and send approve transaction
      final transaction = Transaction(
        from: approveFrom,
        to: approveTo,
        data: approveData,
        value: approveValue,
        gasPrice: EtherAmount.fromBigInt(EtherUnit.wei, approveGasPriceWei),
        maxGas: approveGasLimit,
      );
      
      final signedTx = await _walletService.signRawTx(transaction, chainId: _bscChainId);
      final txHash = await _rpcClient.sendRawTransaction('0x$signedTx');

      dev.log('🔍 SWAP ADAPTER: Approve tx sent: $txHash');

      // Poll for receipt up to ~30s to ensure allowance is active
      const maxWait = Duration(seconds: 30);
      const interval = Duration(seconds: 3);
      final start = DateTime.now();
      while (DateTime.now().difference(start) < maxWait) {
        final receipt = await _rpcClient.getReceipt(txHash);
        if (receipt != null) {
          final ok = receipt.status == true;
          if (!ok) {
            throw AppError.networkError('Approve tx reverted');
          }
          break;
        }
        await Future.delayed(interval);
      }

      return true;
    } catch (e) {
      dev.log('🔍 SWAP ADAPTER: Approval failed: $e');
      throw AppError.allowanceRequired(tokenAddress, 'DEX Router');
    }
  }

  /// Watch transaction status
  SwapWatcher watchTx(String txHash) {
    if (_activeWatchers.containsKey(txHash)) {
      return _activeWatchers[txHash]!;
    }
    
    final watcher = SwapWatcher(
      txHash: txHash,
      rpcClient: _rpcClient,
    );
    
    _activeWatchers[txHash] = watcher;
    watcher.startWatching();
    
    // Clean up after completion
    watcher.statusStream.listen((status) {
      if (status == SwapStatus.confirmed || status == SwapStatus.failed) {
        _activeWatchers.remove(txHash);
      }
    });
    
    return watcher;
  }

  Future<double> getOnchainBalance(String symbol) async {
    try {
      if (!_walletService.isInitialized || _walletService.isLocked) {
        return 0.0;
      }
      final walletAddress = await _walletService.getAddress();
      final tokenAddress = _tokenRegistry.getTokenAddress(symbol);
      if (tokenAddress == null) {
        dev.log('SWAP ADAPTER: Token address not found for $symbol');
        return 0.0;
      }
      final decimals = _tokenRegistry.getTokenDecimals(symbol);
      if (_isNativeToken(tokenAddress)) {
        final wei = await _rpcClient.getBalance(walletAddress);
        return _convertFromWei(wei, 18);
      } else {
        final bal = await _rpcClient.getTokenBalance(walletAddress, tokenAddress);
        return _convertFromWei(bal, decimals);
      }
    } catch (e) {
      dev.log('SWAP ADAPTER: getOnchainBalance error for $symbol -> $e');
      return 0.0;
    }
  }

  BigInt _convertToWei(double amount, int decimals) {
    final amountStr = amount.toStringAsFixed(decimals);
    final parts = amountStr.split('.');
    final integerPart = BigInt.parse(parts[0]);
    final fractionalPart = parts.length > 1 ? parts[1] : '';
    
    // Pad or truncate fractional part to match decimals
    final paddedFractional = fractionalPart.padRight(decimals, '0').substring(0, decimals);
    final fractionalBigInt = paddedFractional.isEmpty ? BigInt.zero : BigInt.parse(paddedFractional);
    
    return integerPart * BigInt.from(10).pow(decimals) + fractionalBigInt;
  }

  double _convertFromWei(BigInt wei, int decimals) {
    final divisor = BigInt.from(10).pow(decimals);
    final integerPart = wei ~/ divisor;
    final fractionalPart = wei % divisor;
    
    return integerPart.toDouble() + fractionalPart.toDouble() / divisor.toDouble();
  }

  bool _isNativeToken(String address) {
    final a = address.toLowerCase();
    // Treat both zero address and 0xEeee... as native (BNB on BSC / ETH on ETH)
    return a == '0x0000000000000000000000000000000000000000' ||
        a == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  }

  void dispose() {
    for (final watcher in _activeWatchers.values) {
      watcher.dispose();
    }
    _activeWatchers.clear();
  }
}

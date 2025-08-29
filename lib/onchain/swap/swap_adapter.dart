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
      
      // Check if approval is needed (skip for native BNB)
      if (!_isNativeToken(fromAddress)) {
        final hasAllowance = await _checkAndApprove(
          tokenAddress: fromAddress,
          walletAddress: walletAddress,
          amountWei: amountWei.toString(),
        );
        
        if (!hasAllowance) {
          return TradeExecResult(
            ok: false,
            base: toSymbol,
            qty: 0.0,
            price: 0.0,
            usdt: 0.0,
            feeRate: 0.0,
            realized: null,
          );
        }
      }

      // Build swap transaction
      final swapResponse = await _inchClient.buildSwapTx(
        fromTokenAddress: fromAddress,
        toTokenAddress: toAddress,
        amountWei: amountWei.toString(),
        fromAddress: walletAddress,
        slippageBps: slippageBps.round(),
      );

      // Create transaction
      final transaction = Transaction(
        from: EthereumAddress.fromHex(swapResponse.tx.from),
        to: EthereumAddress.fromHex(swapResponse.tx.to),
        data: Uint8List.fromList(hex.decode(swapResponse.tx.data.substring(2))),
        value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(swapResponse.tx.value)),
        gasPrice: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(swapResponse.tx.gasPrice)),
        maxGas: int.parse(swapResponse.tx.gas),
      );

      // Sign and send transaction
      final signedTx = await _walletService.signRawTx(transaction, chainId: _bscChainId);
      final txHash = await _rpcClient.sendRawTransaction('0x$signedTx');

      // Calculate output amounts for TradeExecResult
      final toDecimals = _tokenRegistry.getTokenDecimals(toSymbol);
      final outputAmount = _convertFromWei(BigInt.parse(swapResponse.toTokenAmount), toDecimals);
      
      // Get current price for the trade record
      final price = amount > 0 ? outputAmount / amount : 0.0;

      dev.log('🔍 SWAP ADAPTER: Executed swap $fromSymbol->$toSymbol, tx: $txHash');

      // Sync portfolio after successful swap to reflect new balances
      Future.delayed(const Duration(seconds: 10), () {
        _portfolioAdapter.refreshPortfolio();
        dev.log('🔍 SWAP ADAPTER: Portfolio synced after swap completion');
      });

      return TradeExecResult(
        ok: true,
        base: toSymbol,
        qty: outputAmount,
        price: price,
        usdt: fromSymbol == 'USDT' ? amount : outputAmount, // Simplified
        feeRate: 0.003, // 0.3% typical DEX fee
        realized: null,
      );
    } catch (e) {
      dev.log('🔍 SWAP ADAPTER: Swap failed: $e');
      
      AppErrorCode errorCode = AppErrorCode.swapFailed;
      if (e is AppError) {
        errorCode = e.code;
      }
      
      return TradeExecResult(
        ok: false,
        base: toSymbol,
        qty: 0.0,
        price: 0.0,
        usdt: 0.0,
        feeRate: 0.0,
        realized: null,
      );
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
        spenderAddress: spender,
      );
      
      // Create and send approve transaction
      final transaction = Transaction(
        from: EthereumAddress.fromHex(approveTx.from),
        to: EthereumAddress.fromHex(approveTx.to),
        data: Uint8List.fromList(hex.decode(approveTx.data.substring(2))),
        value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(approveTx.value)),
        gasPrice: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(approveTx.gasPrice)),
        maxGas: int.parse(approveTx.gas),
      );
      
      final signedTx = await _walletService.signRawTx(transaction, chainId: _bscChainId);
      final txHash = await _rpcClient.sendRawTransaction('0x$signedTx');
      
      dev.log('🔍 SWAP ADAPTER: Approve tx sent: $txHash');
      
      // Wait for confirmation (simplified - in production, should poll properly)
      await Future.delayed(const Duration(seconds: 5));
      
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
    return address.toLowerCase() == '0x0000000000000000000000000000000000000000';
  }

  void dispose() {
    for (final watcher in _activeWatchers.values) {
      watcher.dispose();
    }
    _activeWatchers.clear();
  }
}

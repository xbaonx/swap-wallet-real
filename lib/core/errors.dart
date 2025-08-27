enum AppErrorCode {
  // Wallet errors
  walletNotInitialized,
  invalidMnemonic,
  invalidPrivateKey,
  walletLocked,
  authenticationFailed,
  
  // Swap errors
  allowanceRequired,
  insufficientFunds,
  slippageExceeded,
  swapFailed,
  
  // Network errors
  networkError,
  timeout,
  rpcSwitched,
  rateLimited,
  
  // General errors
  unknown,
}

class AppError implements Exception {
  final AppErrorCode code;
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppError({
    required this.code,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  factory AppError.walletNotInitialized() => const AppError(
    code: AppErrorCode.walletNotInitialized,
    message: 'Wallet not initialized. Please create or import a wallet first.',
  );

  factory AppError.invalidMnemonic() => const AppError(
    code: AppErrorCode.invalidMnemonic,
    message: 'Invalid mnemonic phrase. Please check and try again.',
  );

  factory AppError.invalidPrivateKey() => const AppError(
    code: AppErrorCode.invalidPrivateKey,
    message: 'Invalid private key format.',
  );

  factory AppError.walletLocked() => const AppError(
    code: AppErrorCode.walletLocked,
    message: 'Wallet is locked. Please unlock first.',
  );

  factory AppError.authenticationFailed() => const AppError(
    code: AppErrorCode.authenticationFailed,
    message: 'Authentication failed. Please verify your credentials.',
  );

  factory AppError.allowanceRequired(String token, String spender) => AppError(
    code: AppErrorCode.allowanceRequired,
    message: 'Token allowance required for $token to $spender',
  );

  factory AppError.insufficientFunds({required double required, required double available}) => AppError(
    code: AppErrorCode.insufficientFunds,
    message: 'Insufficient funds. Required: $required, Available: $available',
  );

  factory AppError.slippageExceeded() => const AppError(
    code: AppErrorCode.slippageExceeded,
    message: 'Transaction would exceed maximum slippage tolerance.',
  );

  factory AppError.networkError(String details) => AppError(
    code: AppErrorCode.networkError,
    message: 'Network error: $details',
  );

  factory AppError.timeout() => const AppError(
    code: AppErrorCode.timeout,
    message: 'Request timed out. Please try again.',
  );

  factory AppError.rpcSwitched(String from, String to) => AppError(
    code: AppErrorCode.rpcSwitched,
    message: 'RPC switched from $from to $to due to failures',
  );

  factory AppError.unknown(dynamic error) => AppError(
    code: AppErrorCode.unknown,
    message: 'Unknown error: $error',
    originalError: error,
  );

  @override
  String toString() => 'AppError(${code.name}): $message';
}

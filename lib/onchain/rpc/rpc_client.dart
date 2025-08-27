import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/http.dart';
import '../../core/errors.dart';

abstract class IRpcClient {
  Future<BigInt> getBalance(String address);
  Future<BigInt> getTokenBalance(String address, String tokenAddress);
  Future<int> getNonce(String address);
  Future<BigInt> estimateGas(Transaction tx);
  Future<String> sendRawTransaction(String signedHex);
  Future<TransactionReceipt?> getReceipt(String txHash);
}

class RpcClient implements IRpcClient {
  late Web3Client _primaryClient;
  late Web3Client _fallbackClient;
  bool _usingFallback = false;
  int _consecutiveFailures = 0;
  
  static const int _maxConsecutiveFailures = 2;
  static const int _bscChainId = 56;

  RpcClient() {
    _initializeClients();
  }

  void _initializeClients() {
    final primaryUrl = dotenv.env['BSC_RPC_URL_PRIMARY'] ?? 'https://bsc-dataseed1.binance.org/';
    final fallbackUrl = dotenv.env['BSC_RPC_URL_FALLBACK'] ?? 'https://bsc-dataseed2.binance.org/';

    _primaryClient = Web3Client(primaryUrl, http.Client());
    _fallbackClient = Web3Client(fallbackUrl, http.Client());
  }

  Web3Client get _currentClient => _usingFallback ? _fallbackClient : _primaryClient;
  String get _currentRpcName => _usingFallback ? 'Fallback' : 'Primary';

  @override
  Future<BigInt> getBalance(String address) async {
    return _withFallback(() async {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _currentClient.getBalance(ethAddress);
      return balance.getInWei;
    });
  }

  @override
  Future<BigInt> getTokenBalance(String address, String tokenAddress) async {
    return _withFallback(() async {
      final contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(_erc20Abi), 'ERC20'),
        EthereumAddress.fromHex(tokenAddress),
      );
      
      final balanceFunction = contract.function('balanceOf');
      final result = await _currentClient.call(
        contract: contract,
        function: balanceFunction,
        params: [EthereumAddress.fromHex(address)],
      );
      
      return result.first as BigInt;
    });
  }

  @override
  Future<int> getNonce(String address) async {
    return _withFallback(() async {
      final ethAddress = EthereumAddress.fromHex(address);
      return await _currentClient.getTransactionCount(ethAddress);
    });
  }

  @override
  Future<BigInt> estimateGas(Transaction tx) async {
    return _withFallback(() async {
      final gasEstimate = await _currentClient.estimateGas(
        sender: tx.from,
        to: tx.to,
        value: tx.value,
        data: tx.data,
      );
      return gasEstimate;
    });
  }

  @override
  Future<String> sendRawTransaction(String signedHex) async {
    return _withFallback(() async {
      // Convert hex string to bytes - remove 0x prefix if present
      final cleanHex = signedHex.startsWith('0x') ? signedHex.substring(2) : signedHex;
      final bytes = <int>[];
      for (int i = 0; i < cleanHex.length; i += 2) {
        bytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
      }
      final txHash = await _currentClient.sendRawTransaction(Uint8List.fromList(bytes));
      return txHash;
    });
  }

  @override
  Future<TransactionReceipt?> getReceipt(String txHash) async {
    return _withFallback(() async {
      return await _currentClient.getTransactionReceipt(txHash);
    });
  }

  Future<T> _withFallback<T>(Future<T> Function() operation) async {
    try {
      final result = await operation();
      _consecutiveFailures = 0; // Reset on success
      return result;
    } catch (e) {
      _consecutiveFailures++;
      
      // Switch to fallback if we've had too many consecutive failures
      if (!_usingFallback && _consecutiveFailures >= _maxConsecutiveFailures) {
        print('RPC_SWITCHED: Switching from Primary to Fallback after $_consecutiveFailures failures');
        _usingFallback = true;
        _consecutiveFailures = 0;
        
        // Try with fallback
        try {
          return await operation();
        } catch (fallbackError) {
          throw _handleRpcError(fallbackError);
        }
      }
      
      throw _handleRpcError(e);
    }
  }

  AppError _handleRpcError(dynamic error) {
    if (error.toString().contains('RPC')) {
      return AppError.networkError('RPC Error ${error.errorCode}: ${error.message}');
    }
    
    return AppError.networkError('RPC call failed: $error');
  }

  void dispose() {
    _primaryClient.dispose();
    _fallbackClient.dispose();
  }

  // ERC-20 ABI for balance queries
  static const List<Map<String, dynamic>> _erc20Abi = [
    {
      "constant": true,
      "inputs": [
        {
          "name": "_owner",
          "type": "address"
        }
      ],
      "name": "balanceOf",
      "outputs": [
        {
          "name": "balance",
          "type": "uint256"
        }
      ],
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {
          "name": "_spender",
          "type": "address"
        },
        {
          "name": "_value",
          "type": "uint256"
        }
      ],
      "name": "approve",
      "outputs": [
        {
          "name": "",
          "type": "bool"
        }
      ],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [
        {
          "name": "_owner",
          "type": "address"
        },
        {
          "name": "_spender",
          "type": "address"
        }
      ],
      "name": "allowance",
      "outputs": [
        {
          "name": "",
          "type": "uint256"
        }
      ],
      "type": "function"
    }
  ];
}

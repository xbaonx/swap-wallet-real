import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/http.dart';
import '../core/errors.dart';
import 'models/oneinch_models.dart';

class InchClient {
  final HttpClient _httpClient;
  final String? _proxyUrl;
  final String _apiKey;
  
  static const String _baseUrl = 'https://api.1inch.dev';
  static const int _bscChainId = 56;

  InchClient()
      : _apiKey = dotenv.env['ONEINCH_API_KEY'] ?? '',
        _proxyUrl = dotenv.env['ONEINCH_PROXY_URL'],
        _httpClient = HttpClient(
          defaultHeaders: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ) {
    // Allow missing API key if using server-side proxy
    if ((_proxyUrl == null || _proxyUrl!.isEmpty) && _apiKey.isEmpty) {
      throw const AppError(
        code: AppErrorCode.unknown,
        message: 'ONEINCH_API_KEY is required in .env file (or set ONEINCH_PROXY_URL to use backend proxy)',
      );
    }
  }

  HttpClient get httpClient => _httpClient;

  Map<String, String> get _authHeaders {
    // When using proxy, API key must be kept server-side. Do not send from client.
    if (_proxyUrl != null && _proxyUrl!.isNotEmpty) {
      return {};
    }
    return {
      'Authorization': 'Bearer $_apiKey',
    };
  }

  String _buildUrl(String endpoint) {
    if (_proxyUrl != null && _proxyUrl!.isNotEmpty) {
      return '$_proxyUrl$endpoint';
    }
    return '$_baseUrl$endpoint';
  }

  /// Get tokens list for BSC (chainId=56)
  Future<OneInchTokensResponse> tokens({int chainId = _bscChainId}) async {
    try {
      final url = _buildUrl('/swap/v6.0/$chainId/tokens');
      final response = await _httpClient.get(
        url,
        headers: _authHeaders,
      );

      return OneInchTokensResponse.fromJson(response.data);
    } catch (e) {
      throw AppError.networkError('Failed to fetch tokens: $e');
    }
  }

  /// Get quote for token swap
  Future<OneInchQuoteResponse> quote({
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amountWei,
    int slippageBps = 50, // 0.5% default slippage
    int chainId = _bscChainId,
  }) async {
    try {
      final url = _buildUrl('/swap/v6.0/$chainId/quote');
      final response = await _httpClient.get(
        url,
        queryParameters: {
          'src': fromTokenAddress,
          'dst': toTokenAddress,
          'amount': amountWei,
          'includeTokensInfo': 'false',
          'includeProtocols': 'false',
          'includeGas': 'true',
        },
        headers: _authHeaders,
      );

      // Debug log actual response to understand structure
      if (kDebugMode) {
        dev.log('🔍 1inch v6 API Response: ${response.data}');
      }
      
      if (response.data == null) {
        throw 'API returned null response';
      }

      return OneInchQuoteResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      dev.log('❗ Quote parsing error: $e');
      throw AppError.networkError('Failed to get quote: $e');
    }
  }

  /// Get allowance for token
  Future<OneInchAllowanceResponse> allowance({
    required String tokenAddress,
    required String walletAddress,
    String? spenderAddress,
    int chainId = _bscChainId,
  }) async {
    try {
      final spender = spenderAddress ?? await _getSpenderAddress(chainId);
      final url = _buildUrl('/swap/v6.0/$chainId/approve/allowance');
      final response = await _httpClient.get(
        url,
        queryParameters: {
          'tokenAddress': tokenAddress,
          'walletAddress': walletAddress,
          'spenderAddress': spender,
        },
        headers: _authHeaders,
      );

      return OneInchAllowanceResponse.fromJson(response.data);
    } catch (e) {
      throw AppError.networkError('Failed to get allowance: $e');
    }
  }

  /// Get spender address for chain
  Future<String> spender({int chainId = _bscChainId}) async {
    try {
      final url = _buildUrl('/swap/v6.0/$chainId/approve/spender');
      final response = await _httpClient.get(
        url,
        headers: _authHeaders,
      );

      final spenderResponse = OneInchSpenderResponse.fromJson(response.data);
      return spenderResponse.address;
    } catch (e) {
      throw AppError.networkError('Failed to get spender: $e');
    }
  }

  Future<String> _getSpenderAddress(int chainId) async {
    return await spender(chainId: chainId);
  }

  /// Build approve transaction
  Future<OneInchTransactionData> buildApproveTx({
    required String tokenAddress,
    required String amountWei,
    required String fromAddress,
    String? spenderAddress,
    int chainId = _bscChainId,
  }) async {
    try {
      final spender = spenderAddress ?? await _getSpenderAddress(chainId);
      final url = _buildUrl('/swap/v6.0/$chainId/approve/transaction');
      final response = await _httpClient.get(
        url,
        queryParameters: {
          'tokenAddress': tokenAddress,
          'amount': amountWei,
          'spenderAddress': spender,
        },
        headers: _authHeaders,
      );

      final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        throw AppError.networkError('1inch approve: empty or invalid response');
      }

      final map = Map<String, dynamic>.from(data);
      // Ensure required fields
      if (map['to'] == null || map['data'] == null) {
        final err = map['description'] ?? map['message'] ?? 'missing to/data';
        throw AppError.networkError('Failed to build approve tx: $err');
      }
      // Fill optional/missing fields
      map['from'] ??= fromAddress;
      map['value'] = (map['value'] ?? '0').toString();
      map['gas'] = (map['gas'] ?? '0').toString();
      map['gasPrice'] = (map['gasPrice'] ?? '0').toString();

      return OneInchTransactionData.fromJson(map);
    } catch (e) {
      throw AppError.networkError('Failed to build approve tx: $e');
    }
  }

  /// Build swap transaction
  Future<OneInchSwapResponse> buildSwapTx({
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amountWei,
    required String fromAddress,
    int slippageBps = 50, // 0.5% default slippage
    int chainId = _bscChainId,
    bool disableEstimate = false,
    bool allowPartialFill = false,
    String? referrerAddress,
    double? referrerFeePercent,
  }) async {
    try {
      final url = _buildUrl('/swap/v6.0/$chainId/swap');
      
      final queryParams = {
        'src': fromTokenAddress,
        'dst': toTokenAddress,
        'amount': amountWei,
        'from': fromAddress,
        'slippage': (slippageBps / 100.0).toString(),
        'disableEstimate': disableEstimate.toString(),
        'allowPartialFill': allowPartialFill.toString(),
        // Ensure tokens info is present to satisfy parser expectations
        'includeTokensInfo': 'true',
        // Referral parameters (1inch format: referrerAddress & fee in percentage)
        if (referrerAddress?.isNotEmpty == true) 'referrerAddress': referrerAddress!,
        if (referrerFeePercent != null && referrerFeePercent > 0) 'fee': referrerFeePercent.toString(),
      };
      
      if (kDebugMode) {
        dev.log('🔍 1inch v6 SWAP Request URL: $url');
        dev.log('🔍 1inch v6 SWAP Request Params: $queryParams');
      }
      
      final response = await _httpClient.get(
        url,
        queryParameters: queryParams,
        headers: _authHeaders,
      );

      if (kDebugMode) {
        dev.log('🔍 1inch v6 SWAP Response Status: ${response.statusCode}');
        dev.log('🔍 1inch v6 SWAP Response: ${response.data}');
      }

      final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        throw AppError.networkError('1inch swap: empty or invalid response');
      }

      // Guard against missing fields on some responses
      final map = Map<String, dynamic>.from(data);
      final txField = map['tx'];
      if (txField == null || txField is! Map) {
        final err = map['description'] ?? map['message'] ?? map.toString();
        throw AppError.networkError('Failed to build swap tx: $err');
      }
      // Normalize tx to a Map<String, dynamic>
      map['tx'] = Map<String, dynamic>.from(txField);

      // Some responses omit token info unless explicitly requested. Ensure parser has defaults.
      map['fromToken'] ??= {
        'symbol': 'UNKNOWN',
        'name': 'Unknown',
        'address': '0x0000000000000000000000000000000000000000',
        'decimals': 18,
      };
      map['toToken'] ??= {
        'symbol': 'UNKNOWN',
        'name': 'Unknown',
        'address': '0x0000000000000000000000000000000000000000',
        'decimals': 18,
      };

      // Map v6 amount fields if present (some responses use srcAmount/dstAmount)
      // Ensure our models receive string amounts to prevent type issues
      map['fromTokenAmount'] ??= (map['srcAmount'] ?? map['fromAmount'])?.toString();
      map['toTokenAmount'] ??= (map['dstAmount'] ?? map['toAmount'])?.toString();

      return OneInchSwapResponse.fromJson(map);
    } catch (e) {
      throw AppError.networkError('Failed to build swap tx: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

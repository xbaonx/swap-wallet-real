import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    if (_apiKey.isEmpty) {
      throw AppError(
        code: AppErrorCode.unknown,
        message: 'ONEINCH_API_KEY is required in .env file',
      );
    }
  }

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_apiKey',
      };

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

      // Debug: Print actual response to understand structure
      print('🔍 1inch v6 API Response: ${response.data}');
      
      if (response.data == null) {
        throw 'API returned null response';
      }

      return OneInchQuoteResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      print('❗ Quote parsing error: $e');
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

      return OneInchTransactionData.fromJson(response.data);
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
  }) async {
    try {
      final url = _buildUrl('/swap/v6.0/$chainId/swap');
      final response = await _httpClient.get(
        url,
        queryParameters: {
          'src': fromTokenAddress,
          'dst': toTokenAddress,
          'amount': amountWei,
          'from': fromAddress,
          'slippage': (slippageBps / 100.0).toString(),
          'disableEstimate': disableEstimate.toString(),
          'allowPartialFill': allowPartialFill.toString(),
        },
        headers: _authHeaders,
      );

      return OneInchSwapResponse.fromJson(response.data);
    } catch (e) {
      throw AppError.networkError('Failed to build swap tx: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

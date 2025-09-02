import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/http.dart';
import '../core/errors.dart';
import 'models/moralis_models.dart';

class MoralisClient {
  final HttpClient _httpClient;
  final String? _proxyUrl;
  final String _apiKey;
  
  static const String _baseUrl = 'https://deep-index.moralis.io/api/v2.2';
  static const String _bscChain = 'bsc';
  static const Map<String, String> _wrappedNativeByChain = {
    // EVM chain -> wrapped native token contract on that chain
    'bsc': '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', // WBNB
    'eth': '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
    'polygon': '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270', // WMATIC
  };

  MoralisClient()
      : _apiKey = dotenv.env['MORALIS_API_KEY'] ?? '',
        _proxyUrl = dotenv.env['MORALIS_PROXY_URL'],
        _httpClient = HttpClient(
          defaultHeaders: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ) {
    // Cho phép thiếu API key nếu đang dùng proxy server-side
    if ((_proxyUrl == null || _proxyUrl!.isEmpty) && _apiKey.isEmpty) {
      throw const AppError(
        code: AppErrorCode.unknown,
        message: 'MORALIS_API_KEY is required in .env file (hoặc đặt MORALIS_PROXY_URL để dùng backend proxy)',
      );
    }
  }

  Map<String, String> get _authHeaders {
    if (_proxyUrl != null && _proxyUrl!.isNotEmpty) {
      // When using proxy, headers might be handled differently
      return {};
    }
    return {
      'X-API-Key': _apiKey,
    };
  }

  String _buildUrl(String endpoint) {
    if (_proxyUrl != null && _proxyUrl!.isNotEmpty) {
      return '$_proxyUrl$endpoint';
    }
    return '$_baseUrl$endpoint';
  }

  /// Get wallet token balances for BSC
  Future<MoralisTokenBalancesResponse> walletTokenBalances({
    required String address,
    String chain = _bscChain,
    List<String>? tokenAddresses,
    String? cursor,
    int limit = 100,
    bool excludeSpam = true,
    bool excludeUnverifiedContracts = true,
  }) async {
    try {
      final url = _buildUrl('/$address/erc20');
      final queryParams = <String, dynamic>{
        'chain': chain,
        'limit': limit.toString(),
        'exclude_spam': excludeSpam.toString(),
        'exclude_unverified_contracts': excludeUnverifiedContracts.toString(),
      };

      if (tokenAddresses != null && tokenAddresses.isNotEmpty) {
        queryParams['token_addresses'] = tokenAddresses.join(',');
      }

      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }

      final response = await _httpClient.get(
        url,
        queryParameters: queryParams,
        headers: _authHeaders,
      );

      if (kDebugMode) {
        dev.log('🔍 MORALIS DEBUG: Raw response type: ${response.data.runtimeType}');
        dev.log('🔍 MORALIS DEBUG: Raw response: ${response.data}');
      }

      // Handle both direct array and wrapped response formats
      final responseData = response.data;
      if (responseData is List) {
        // Direct array format
        final tokenBalances = responseData
            .map((item) => MoralisTokenBalance.fromJson(item as Map<String, dynamic>))
            .toList();
        return MoralisTokenBalancesResponse(result: tokenBalances, cursor: null);
      } else if (responseData is Map<String, dynamic>) {
        // Wrapped format
        return MoralisTokenBalancesResponse.fromJson(responseData);
      } else {
        throw AppError.networkError('Unexpected response format: ${responseData.runtimeType}');
      }
    } catch (e) {
      throw AppError.networkError('Failed to fetch wallet balances: $e');
    }
  }

  /// Get wallet token transfers/history for BSC
  Future<MoralisTokenTransfersResponse> walletTokenTransfers({
    required String address,
    String chain = _bscChain,
    String? cursor,
    int limit = 100,
    String? fromDate,
    String? toDate,
    List<String>? contractAddresses,
  }) async {
    try {
      final url = _buildUrl('/$address/erc20/transfers');
      final queryParams = <String, dynamic>{
        'chain': chain,
        'limit': limit.toString(),
      };

      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }

      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from_date'] = fromDate;
      }

      if (toDate != null && toDate.isNotEmpty) {
        queryParams['to_date'] = toDate;
      }

      if (contractAddresses != null && contractAddresses.isNotEmpty) {
        queryParams['contract_addresses'] = contractAddresses.join(',');
      }

      final response = await _httpClient.get(
        url,
        queryParameters: queryParams,
        headers: _authHeaders,
      );

      return MoralisTokenTransfersResponse.fromJson(response.data);
    } catch (e) {
      throw AppError.networkError('Failed to fetch token transfers: $e');
    }
  }

  /// Get token price in USD for BSC
  Future<MoralisTokenPrice> tokenPrice({
    required String tokenAddress,
    String chain = _bscChain,
    String? exchange,
    String? toBlock,
  }) async {
    try {
      final url = _buildUrl('/erc20/$tokenAddress/price');
      final queryParams = <String, dynamic>{
        'chain': chain,
      };

      if (exchange != null && exchange.isNotEmpty) {
        queryParams['exchange'] = exchange;
      }

      if (toBlock != null && toBlock.isNotEmpty) {
        queryParams['to_block'] = toBlock;
      }

      final response = await _httpClient.get(
        url,
        queryParameters: queryParams,
        headers: _authHeaders,
      );

      return MoralisTokenPrice.fromJson(response.data);
    } catch (e) {
      throw AppError.networkError('Failed to fetch token price: $e');
    }
  }

  /// Get BNB price (native token for BSC)
  Future<double> getBnbPrice() async {
    try {
      // BSC native token (BNB) address is typically 0x0000000000000000000000000000000000000000
      // But Moralis might handle it differently, we'll use a well-known wrapped BNB address
      const wbnbAddress = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c';
      final priceData = await tokenPrice(tokenAddress: wbnbAddress);
      return priceData.usdPrice;
    } catch (e) {
      throw AppError.networkError('Failed to fetch BNB price: $e');
    }
  }

  /// Get native token price for a specific EVM chain (e.g., ETH for eth, MATIC for polygon)
  Future<double> getNativePrice({required String chain}) async {
    try {
      final tokenAddress = _wrappedNativeByChain[chain];
      if (tokenAddress == null) {
        throw AppError(
          code: AppErrorCode.unknown,
          message: 'Unsupported chain for native price: $chain',
        );
      }
      final priceData = await tokenPrice(tokenAddress: tokenAddress, chain: chain);
      return priceData.usdPrice;
    } catch (e) {
      throw AppError.networkError('Failed to fetch native price for $chain: $e');
    }
  }

  /// Get native balance (BNB) for address
  Future<String> getNativeBalance({
    required String address,
    String chain = _bscChain,
  }) async {
    try {
      final url = _buildUrl('/$address/balance');
      final queryParams = <String, dynamic>{
        'chain': chain,
      };

      final response = await _httpClient.get(
        url,
        queryParameters: queryParams,
        headers: _authHeaders,
      );

      return response.data['balance'] as String;
    } catch (e) {
      throw AppError.networkError('Failed to fetch native balance: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

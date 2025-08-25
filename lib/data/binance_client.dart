import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class BinanceClient {
  static const _timeout = Duration(seconds: 10);

  Future<Map<String, dynamic>> getAllBookTickers() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.binanceBaseUrl}${AppConstants.bookTickerEndpoint}'),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return {
          for (var item in data)
            item['symbol']: {
              'bid': double.parse(item['bidPrice']),
              'ask': double.parse(item['askPrice']),
            }
        };
      }
      throw Exception('Failed to load book tickers: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getAll24hStats() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.binanceBaseUrl}${AppConstants.stats24hEndpoint}'),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return {
          for (var item in data)
            item['symbol']: {
              'priceChangePercent': double.parse(item['priceChangePercent']),
              'quoteVolume': double.parse(item['quoteVolume']),
              'lastPrice': double.parse(item['lastPrice']),
            }
        };
      }
      throw Exception('Failed to load 24h stats: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<double>> getKlines(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.binanceBaseUrl}${AppConstants.klinesEndpoint}?symbol=$symbol&interval=1h&limit=24'),
        headers: {'Accept': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map<double>((kline) => double.parse(kline[4])).toList(); // Close prices
      }
      throw Exception('Failed to load klines: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

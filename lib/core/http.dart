import 'dart:io';
import 'package:dio/dio.dart';
import 'errors.dart';

class HttpConfig {
  static const int defaultTimeoutSeconds = 15;
  static const int maxRetries = 2;
  static const Duration retryDelay = Duration(seconds: 1);
}

class HttpClient {
  final Dio _dio;

  HttpClient({
    int timeoutSeconds = HttpConfig.defaultTimeoutSeconds,
    Map<String, String>? defaultHeaders,
  }) : _dio = Dio(BaseOptions(
          connectTimeout: Duration(seconds: timeoutSeconds),
          receiveTimeout: Duration(seconds: timeoutSeconds),
          sendTimeout: Duration(seconds: timeoutSeconds),
          headers: defaultHeaders,
        )) {
    // HTTP logging disabled to reduce spam
    // _dio.interceptors.add(LogInterceptor(...));
  }

  /// GET request with automatic retry (0-2 times with exponential backoff)
  Future<Response> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    int maxRetries = HttpConfig.maxRetries,
  }) async {
    return _withRetry(
      () => _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      ),
      maxRetries: maxRetries,
    );
  }

  /// POST request without retry (for swap transactions)
  Future<Response> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      return await _dio.post(
        url,
        data: data,
        options: Options(headers: headers),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request without retry
  Future<Response> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      return await _dio.put(
        url,
        data: data,
        options: Options(headers: headers),
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> _withRetry(
    Future<Response> Function() operation, {
    required int maxRetries,
  }) async {
    int attempt = 0;
    
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt > maxRetries || !_shouldRetry(e)) {
          throw _handleError(e);
        }
        
        // Exponential backoff: 1s, 2s, 4s...
        final delay = Duration(
          milliseconds: HttpConfig.retryDelay.inMilliseconds * (1 << (attempt - 1)),
        );
        
        // Retrying HTTP request
        await Future.delayed(delay);
      }
    }
  }

  bool _shouldRetry(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
             error.type == DioExceptionType.receiveTimeout ||
             error.type == DioExceptionType.sendTimeout ||
             (error.response?.statusCode ?? 0) >= 500;
    }
    return error is SocketException || error is HandshakeException;
  }

  AppError _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return AppError.timeout();
          
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode ?? 0;
          if (statusCode == 429) {
            return AppError(
              code: AppErrorCode.rateLimited,
              message: 'Rate limited. Please try again later.',
              originalError: error,
            );
          }
          return AppError.networkError('HTTP $statusCode: ${error.message}');
          
        default:
          return AppError.networkError(error.message ?? 'Network error');
      }
    }
    
    if (error is SocketException || error is HandshakeException) {
      return AppError.networkError(error.toString());
    }
    
    return AppError.unknown(error);
  }

  void close() {
    _dio.close();
  }
}

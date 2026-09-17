import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  // USB development works through `adb reverse tcp:8000 tcp:8000`.
  // For Wi-Fi/mobile testing, set the laptop address in Settings.
  static const String defaultBaseUrl = 'http://localhost:8000';
  static const Duration timeout = Duration(seconds: 15);

  static String get initialBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) return defined;
    return defaultBaseUrl;
  }
}

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.initialBaseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Read custom saved server URL if user changed it in-app
        final customUrl = await _storage.read(key: 'custom_base_url');
        if (customUrl != null && customUrl.isNotEmpty) {
          options.baseUrl = customUrl;
        }

        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _storage.delete(key: 'jwt_token');
          _storage.delete(key: 'user_data');
        }
        handler.next(error);
      },
    ));
  }

  Future<String> getBaseUrl() async {
    final saved = await _storage.read(key: 'custom_base_url');
    if (saved != null && saved.isNotEmpty) return saved;
    return dio.options.baseUrl;
  }

  Future<void> updateBaseUrl(String newUrl) async {
    var cleanUrl = newUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    await _storage.write(key: 'custom_base_url', value: cleanUrl);
    dio.options.baseUrl = cleanUrl;
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_data');
  }
}

class ApiConfig {
  // Production: HTTPS kullan
  // Development: HTTP + local IP
  static const bool _isProd = bool.fromEnvironment('PROD', defaultValue: false);

  static const String _prodUrl = 'https://stoksay.com/api';
  static const String _devUrl = String.fromEnvironment('DEV_URL', defaultValue: 'http://172.22.23.243:3001/api');

  static String get baseUrl => _isProd ? _prodUrl : _devUrl;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const String tokenKey = 'stoksay-token';
}

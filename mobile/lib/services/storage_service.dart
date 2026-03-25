import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static SharedPreferences? _prefs;
  static String? _cachedToken;
  static bool _offlineMode = false;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Eski SharedPreferences'tan token varsa secure storage'a taşı
    final oldToken = _prefs?.getString(ApiConfig.tokenKey);
    if (oldToken != null) {
      await _secureStorage.write(key: ApiConfig.tokenKey, value: oldToken);
      await _prefs?.remove(ApiConfig.tokenKey);
    }

    // Secure storage'dan token'ı cache'le
    _cachedToken = await _secureStorage.read(key: ApiConfig.tokenKey);

    // Offline mod durumunu yükle
    _offlineMode = _prefs?.getBool('offline_mode') ?? false;
  }

  static bool get hasToken => _cachedToken != null && !isTokenExpired;
  static String? get token => _cachedToken;

  /// JWT token'ın süresinin dolup dolmadığını kontrol eder
  static bool get isTokenExpired {
    if (_cachedToken == null) return true;
    try {
      final parts = _cachedToken!.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return true;
      // 30 saniye tampon — süresi dolmak üzereyse de expired say
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 30;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: ApiConfig.tokenKey, value: token);
    _cachedToken = token;
  }

  static Future<void> removeToken() async {
    await _secureStorage.delete(key: ApiConfig.tokenKey);
    _cachedToken = null;
  }

  // ── Offline Mod ──

  /// Offline modda mı? (senkron okuma)
  static bool get isOffline => _offlineMode;

  static Future<void> setOfflineMode(bool value) async {
    _offlineMode = value;
    await _prefs?.setBool('offline_mode', value);
  }
}

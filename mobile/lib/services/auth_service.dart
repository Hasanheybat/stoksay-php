import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static Future<void> login(String email, String password) async {
    final res = await ApiService.dio.post('/auth/login', data: {
      'email': email,
      'sifre': password,
    });
    final token = res.data['token'];
    if (token != null) {
      await StorageService.saveToken(token);
    }
  }

  static Future<Map<String, dynamic>> oturumKontrol() async {
    final res = await ApiService.dio.get('/auth/me');
    return Map<String, dynamic>.from(res.data);
  }

  static Future<void> logout() async {
    await StorageService.removeToken();
  }
}

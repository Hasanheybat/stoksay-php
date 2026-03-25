import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static final Dio _dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = StorageService.token;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await StorageService.removeToken();
        }
        // 500 hatalarında sunucu detaylarını gizle
        if (error.response?.statusCode != null && error.response!.statusCode! >= 500) {
          error.response!.data = {'hata': 'Sunucu hatasi. Lutfen tekrar deneyin.'};
        }
        handler.next(error);
      },
    ));

    return dio;
  }

  static Dio get dio => _dio;
}

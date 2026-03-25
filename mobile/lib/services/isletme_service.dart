import '../models/isletme.dart';
import 'api_service.dart';

class IsletmeService {
  static Future<List<Isletme>> isletmelerim() async {
    final res = await ApiService.dio.get('/profil/isletmelerim');
    final list = res.data as List;
    return list.map((e) => Isletme.fromJson(e)).toList();
  }
}

import 'package:sqflite/sqflite.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../db/database_helper.dart';

class ProfilService {
  static Future<Map<String, dynamic>> stats(String isletmeId) async {
    if (StorageService.isOffline) return _statsOffline(isletmeId);
    final res = await ApiService.dio.get('/profil/stats', queryParameters: {'isletme_id': isletmeId});
    return Map<String, dynamic>.from(res.data);
  }

  static Future<void> ayarlarGuncelle(Map<String, dynamic> ayarlar) async {
    // Ayarlar sadece online modda güncellenebilir
    await ApiService.dio.put('/profil/ayarlar', data: ayarlar);
  }

  static Future<Map<String, dynamic>> _statsOffline(String isletmeId) async {
    final db = await DatabaseHelper.database;

    final urunSayisi = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM urunler WHERE isletme_id = ? AND aktif = 1', [isletmeId],
    )) ?? 0;

    final depoSayisi = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM depolar WHERE isletme_id = ? AND aktif = 1', [isletmeId],
    )) ?? 0;

    final sayimSayisi = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM sayimlar WHERE isletme_id = ? AND durum != 'silindi'", [isletmeId],
    )) ?? 0;

    final devamEden = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM sayimlar WHERE isletme_id = ? AND durum = 'devam'", [isletmeId],
    )) ?? 0;

    return {
      'urun_sayisi': urunSayisi,
      'depo_sayisi': depoSayisi,
      'sayim_sayisi': sayimSayisi,
      'devam_eden': devamEden,
    };
  }
}

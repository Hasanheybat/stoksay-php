import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'offline_id_service.dart';
import '../db/database_helper.dart';
import '../db/sync_service.dart';

/// Aktif sayımda kullanılan kayıt silinmeye çalışıldığında fırlatılır.
class AktifSayimException implements Exception {
  final String mesaj;
  final List<String> sayimAdlari;
  AktifSayimException(this.mesaj, this.sayimAdlari);
  @override
  String toString() => mesaj;
}

class DepoService {
  // ── Ana Metodlar (offline/online yönlendirme) ──

  static Future<List<Map<String, dynamic>>> listele(String isletmeId) async {
    if (StorageService.isOffline) return _listeleOffline(isletmeId);
    return listeleOnline(isletmeId);
  }

  static Future<Map<String, dynamic>> ekle(String isletmeId, String ad, {String? konum}) async {
    if (StorageService.isOffline) return _ekleOffline(isletmeId, ad, konum: konum);
    return ekleOnline(isletmeId, ad, konum: konum);
  }

  static Future<Map<String, dynamic>> guncelle(dynamic id, Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _guncelleOffline(id, data);
    return guncelleOnline(id, data);
  }

  static Future<void> sil(dynamic id, {String? isletmeId}) async {
    if (StorageService.isOffline) return _silOffline(id);

    // Online modda da aktif sayım kontrolü yap (API'den)
    if (isletmeId != null) {
      final res = await ApiService.dio.get('/sayimlar', queryParameters: {
        'isletme_id': isletmeId,
        'depo_id': id.toString(),
        'durum': 'devam',
        'sayfa': '1',
        'limit': '20',
      });
      final data = res.data;
      final list = data is Map && data['data'] is List
          ? data['data'] as List
          : (data is List ? data : []);
      if (list.isNotEmpty) {
        final adlar = list.map((s) => s['ad']?.toString() ?? 'İsimsiz sayım').toList().cast<String>();
        throw AktifSayimException(
          'Bu depo aktif sayımlarda kullanılıyor.',
          adlar,
        );
      }
    }

    try {
      return await silOnline(id);
    } on DioException catch (e) {
      // Backend 409 döndürürse aktif sayım hatası (backend deploy edildikten sonra)
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final hata = data is Map ? data['hata']?.toString() ?? '' : '';
        final sayimAdlari = data is Map && data['sayimlar'] is List
            ? (data['sayimlar'] as List).map((s) => s.toString()).toList()
            : <String>[];
        throw AktifSayimException(
          hata.isNotEmpty ? hata : 'Bu depo aktif sayımlarda kullanılıyor.',
          sayimAdlari,
        );
      }
      rethrow;
    }
  }

  // ── Online Metodlar (API) ──

  static Future<List<Map<String, dynamic>>> listeleOnline(String isletmeId) async {
    final res = await ApiService.dio.get('/depolar', queryParameters: {'isletme_id': isletmeId, 'sayfa': 1, 'limit': 500});
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(raw['data']);
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  static Future<Map<String, dynamic>> ekleOnline(String isletmeId, String ad, {String? konum}) async {
    final data = <String, dynamic>{'isletme_id': isletmeId, 'ad': ad};
    if (konum != null) data['konum'] = konum;
    final res = await ApiService.dio.post('/depolar', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> guncelleOnline(dynamic id, Map<String, dynamic> data) async {
    final res = await ApiService.dio.put('/depolar/$id', data: data);
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {};
  }

  static Future<void> silOnline(dynamic id) async {
    await ApiService.dio.delete('/depolar/$id');
  }

  // ── Offline Metodlar (SQLite) ──

  static Future<List<Map<String, dynamic>>> _listeleOffline(String isletmeId) async {
    final db = await DatabaseHelper.database;
    return db.query('depolar', where: 'isletme_id = ? AND aktif = 1', whereArgs: [isletmeId]);
  }

  static Future<Map<String, dynamic>> _ekleOffline(String isletmeId, String ad, {String? konum}) async {
    final db = await DatabaseHelper.database;
    final tempId = await OfflineIdService.nextId();
    final row = {
      'id': tempId,
      'ad': ad,
      'konum': konum,
      'isletme_id': isletmeId,
      'aktif': 1,
      'son_guncelleme': DateTime.now().toIso8601String(),
    };
    await db.insert('depolar', row);
    await SyncService.kuyruguEkle('depolar', 'ekle', {
      ...row,
      '_temp_id': tempId,
    });
    return row;
  }

  static Future<Map<String, dynamic>> _guncelleOffline(dynamic id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    await db.update('depolar', data, where: 'id = ?', whereArgs: [id]);

    if (OfflineIdService.isTempId(id)) {
      // Temp ID: henüz sunucuya gitmemiş
    } else {
      await SyncService.kuyruguEkle('depolar', 'guncelle', {'id': id, ...data});
    }

    final rows = await db.query('depolar', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : {};
  }

  static Future<void> _silOffline(dynamic id) async {
    final db = await DatabaseHelper.database;
    final idStr = id?.toString() ?? '';

    // Aktif sayımda kullanılıyor mu kontrol et
    final aktifSayimlar = await db.query('sayimlar',
      where: "depo_id = ? AND durum = 'devam'",
      whereArgs: [idStr],
    );
    if (aktifSayimlar.isNotEmpty) {
      final adlar = aktifSayimlar.map((s) => s['ad']?.toString() ?? 'İsimsiz sayım').toList();
      throw AktifSayimException(
        'Bu depo aktif sayımlarda kullanılıyor.',
        adlar,
      );
    }

    // Soft delete: aktif=0 yap + queue'ya sil ekle
    // Temp ID ise: sync sırasında önce ekle çalışır (depo oluşur), sonra sil çalışır
    // Server ID ise: sync sırasında doğrudan sil çalışır
    await db.update('depolar', {'aktif': 0}, where: 'id = ?', whereArgs: [id]);
    await SyncService.kuyruguEkle('depolar', 'sil', {'id': id});
  }
}

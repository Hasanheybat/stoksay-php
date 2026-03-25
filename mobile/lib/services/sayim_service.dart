import 'dart:convert';
import 'api_service.dart';
import 'storage_service.dart';
import 'offline_id_service.dart';
import '../db/database_helper.dart';
import '../db/sync_service.dart';

class SayimService {
  // ── Ana Metodlar (offline/online yönlendirme) ──

  static Future<List<Map<String, dynamic>>> listele(String isletmeId) async {
    if (StorageService.isOffline) return _listeleOffline(isletmeId);
    return listeleOnline(isletmeId);
  }

  static Future<Map<String, dynamic>> detay(String sayimId) async {
    if (StorageService.isOffline) return _detayOffline(sayimId);
    return detayOnline(sayimId);
  }

  static Future<Map<String, dynamic>> olustur(Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _olusturOffline(data);
    return olusturOnline(data);
  }

  static Future<Map<String, dynamic>> guncelle(dynamic id, Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _guncelleOffline(id, data);
    return guncelleOnline(id, data);
  }

  static Future<void> sil(dynamic id) async {
    if (StorageService.isOffline) return _silOffline(id);
    return silOnline(id);
  }

  static Future<void> tamamla(dynamic id) async {
    if (StorageService.isOffline) return _tamamlaOffline(id);
    return tamamlaOnline(id);
  }

  static Future<List<Map<String, dynamic>>> kalemListele(dynamic sayimId) async {
    if (StorageService.isOffline) return _kalemListeleOffline(sayimId);
    return kalemListeleOnline(sayimId);
  }

  static Future<Map<String, dynamic>> kalemEkle(dynamic sayimId, Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _kalemEkleOffline(sayimId, data);
    return kalemEkleOnline(sayimId, data);
  }

  static Future<void> kalemGuncelle(dynamic sayimId, dynamic kalemId, Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _kalemGuncelleOffline(sayimId, kalemId, data);
    return kalemGuncelleOnline(sayimId, kalemId, data);
  }

  static Future<void> kalemSil(dynamic sayimId, dynamic kalemId) async {
    if (StorageService.isOffline) return _kalemSilOffline(sayimId, kalemId);
    return kalemSilOnline(sayimId, kalemId);
  }

  static Future<Map<String, dynamic>> topla({
    required List<String> sayimIds,
    required String ad,
    required String isletmeId,
  }) async {
    if (StorageService.isOffline) return _toplaOffline(sayimIdleri: sayimIds, ad: ad, isletmeId: isletmeId);
    return toplaOnline(sayimIdleri: sayimIds, ad: ad, isletmeId: isletmeId);
  }

  static Future<List<Map<String, dynamic>>> toplanmisListele(String isletmeId) async {
    if (StorageService.isOffline) return _toplanmisListeleOffline(isletmeId);
    return toplanmisListeleOnline(isletmeId);
  }

  // ── Online Metodlar (API) ──

  static Future<List<Map<String, dynamic>>> listeleOnline(String isletmeId) async {
    final res = await ApiService.dio.get('/sayimlar', queryParameters: {'isletme_id': isletmeId, 'limit': 500, 'toplama': '0'});
    final raw = res.data;
    if (raw is Map && raw['data'] is List) return List<Map<String, dynamic>>.from(raw['data']);
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  static Future<Map<String, dynamic>> detayOnline(String sayimId) async {
    final res = await ApiService.dio.get('/sayimlar/$sayimId');
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> olusturOnline(Map<String, dynamic> data) async {
    final res = await ApiService.dio.post('/sayimlar', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> guncelleOnline(dynamic id, Map<String, dynamic> data) async {
    final res = await ApiService.dio.put('/sayimlar/$id', data: data);
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {};
  }

  static Future<void> silOnline(dynamic id) async {
    await ApiService.dio.delete('/sayimlar/$id');
  }

  static Future<void> tamamlaOnline(dynamic id) async {
    await ApiService.dio.put('/sayimlar/$id/tamamla');
  }

  static Future<List<Map<String, dynamic>>> kalemListeleOnline(dynamic sayimId) async {
    final res = await ApiService.dio.get('/sayimlar/$sayimId/kalemler');
    final raw = res.data;
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    if (raw is Map && raw['data'] is List) return List<Map<String, dynamic>>.from(raw['data']);
    return [];
  }

  static Future<Map<String, dynamic>> kalemEkleOnline(dynamic sayimId, Map<String, dynamic> data) async {
    final res = await ApiService.dio.post('/sayimlar/$sayimId/kalem', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  static Future<void> kalemGuncelleOnline(dynamic sayimId, dynamic kalemId, Map<String, dynamic> data) async {
    await ApiService.dio.put('/sayimlar/$sayimId/kalem/$kalemId', data: data);
  }

  static Future<void> kalemSilOnline(dynamic sayimId, dynamic kalemId) async {
    await ApiService.dio.delete('/sayimlar/$sayimId/kalem/$kalemId');
  }

  static Future<Map<String, dynamic>> toplaOnline({
    required List<String> sayimIdleri,
    required String ad,
    required String isletmeId,
  }) async {
    final res = await ApiService.dio.post('/sayimlar/topla', data: {
      'sayim_ids': sayimIdleri,
      'ad': ad,
      'isletme_id': isletmeId,
    });
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {};
  }

  static Future<List<Map<String, dynamic>>> toplanmisListeleOnline(String isletmeId) async {
    final res = await ApiService.dio.get('/sayimlar', queryParameters: {
      'isletme_id': isletmeId,
      'toplama': '1',
      'limit': 500,
    });
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from((raw['data'] as List).where((s) => s['durum'] != 'silindi'));
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw.where((s) => s['durum'] != 'silindi'));
    return [];
  }

  // ── Offline Metodlar (SQLite) ──

  static Future<List<Map<String, dynamic>>> _listeleOffline(String isletmeId) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('sayimlar',
      where: "isletme_id = ? AND durum != 'silindi'",
      whereArgs: [isletmeId],
      orderBy: 'tarih DESC',
    );

    // Toplanan sayımları filtrele + nested objeleri ekle
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final notlar = row['notlar'] as String?;
      // Toplanan sayımları atla
      if (notlar != null && notlar.isNotEmpty) {
        try {
          final parsed = jsonDecode(notlar);
          if (parsed is Map && parsed.containsKey('toplanan_sayimlar')) continue;
        } catch (_) {}
      }

      final sayim = Map<String, dynamic>.from(row);

      // kisiler JSON → List
      if (sayim['kisiler'] is String) {
        try {
          sayim['kisiler'] = jsonDecode(sayim['kisiler'] as String);
        } catch (_) {
          sayim['kisiler'] = [];
        }
      }

      // Depo bilgisini ekle (ekranlar depolar.ad bekliyor)
      if (sayim['depo_id'] != null) {
        final depoRows = await db.query('depolar', where: 'id = ?', whereArgs: [sayim['depo_id']]);
        if (depoRows.isNotEmpty) {
          sayim['depolar'] = {'id': depoRows.first['id'], 'ad': depoRows.first['ad']};
        } else if (sayim['depo_adi'] != null) {
          // Depo silinmiş olabilir — kayıtlı adı kullan
          sayim['depolar'] = {'id': sayim['depo_id'], 'ad': sayim['depo_adi']};
        }
      }

      result.add(sayim);
    }
    return result;
  }

  static Future<Map<String, dynamic>> _detayOffline(dynamic sayimId) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('sayimlar', where: 'id = ?', whereArgs: [sayimId]);
    if (rows.isEmpty) return {};

    final sayim = Map<String, dynamic>.from(rows.first);

    // Depo bilgisini ekle
    if (sayim['depo_id'] != null) {
      final depoRows = await db.query('depolar', where: 'id = ?', whereArgs: [sayim['depo_id']]);
      if (depoRows.isNotEmpty) {
        sayim['depolar'] = {'id': depoRows.first['id'], 'ad': depoRows.first['ad']};
      } else if (sayim['depo_adi'] != null) {
        sayim['depolar'] = {'id': sayim['depo_id'], 'ad': sayim['depo_adi']};
      }
    }

    // İşletme bilgisini ekle
    if (sayim['isletme_id'] != null) {
      final isletmeRows = await db.query('isletmeler', where: 'id = ?', whereArgs: [sayim['isletme_id']]);
      if (isletmeRows.isNotEmpty) {
        sayim['isletmeler'] = {'id': isletmeRows.first['id'], 'ad': isletmeRows.first['ad']};
      }
    }

    // kisiler JSON'dan List'e çevir
    if (sayim['kisiler'] is String) {
      try {
        sayim['kisiler'] = jsonDecode(sayim['kisiler'] as String);
      } catch (_) {
        sayim['kisiler'] = [];
      }
    }

    return sayim;
  }

  static Future<Map<String, dynamic>> _olusturOffline(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final tempId = await OfflineIdService.nextId();
    // Depo adını bul ve kaydet
    String? depoAdi;
    if (data['depo_id'] != null) {
      final depoRows = await db.query('depolar', where: 'id = ?', whereArgs: [data['depo_id']]);
      if (depoRows.isNotEmpty) depoAdi = depoRows.first['ad']?.toString();
    }

    final row = {
      'id': tempId,
      'ad': data['ad'],
      'tarih': data['tarih'] ?? DateTime.now().toIso8601String(),
      'durum': 'devam',
      'isletme_id': data['isletme_id'],
      'depo_id': data['depo_id'],
      'depo_adi': depoAdi,
      'kullanici_id': data['kullanici_id'],
      'kisiler': jsonEncode(data['kisiler'] ?? []),
      'notlar': data['notlar'] ?? '',
      'son_guncelleme': DateTime.now().toIso8601String(),
    };
    await db.insert('sayimlar', row);
    await SyncService.kuyruguEkle('sayimlar', 'ekle', {
      ...data,
      '_temp_id': tempId,
    });
    // Depo bilgisini ekle
    final result = Map<String, dynamic>.from(row);
    result['id'] = tempId.toString();
    result['kisiler'] = data['kisiler'] ?? [];
    if (data['depo_id'] != null) {
      final depoRows = await db.query('depolar', where: 'id = ?', whereArgs: [data['depo_id']]);
      if (depoRows.isNotEmpty) {
        result['depolar'] = {'id': depoRows.first['id'], 'ad': depoRows.first['ad']};
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> _guncelleOffline(dynamic id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final updateData = Map<String, dynamic>.from(data);
    if (updateData['kisiler'] is List) {
      updateData['kisiler'] = jsonEncode(updateData['kisiler']);
    }
    updateData['son_guncelleme'] = DateTime.now().toIso8601String();
    await db.update('sayimlar', updateData, where: 'id = ?', whereArgs: [id]);

    if (OfflineIdService.isTempId(id)) {
      // Henüz sunucuya gitmemiş
    } else {
      await SyncService.kuyruguEkle('sayimlar', 'guncelle', {'id': id, ...data});
    }

    return _detayOffline(id);
  }

  static Future<void> _silOffline(dynamic id) async {
    final db = await DatabaseHelper.database;

    // Hem temp hem server: soft delete (durum='silindi') + queue'ya sil ekle
    // Temp ise: sync sırasında önce ekle çalışır (sayım oluşur), sonra sil çalışır
    await db.update('sayimlar', {'durum': 'silindi'}, where: 'id = ?', whereArgs: [id]);
    await SyncService.kuyruguEkle('sayimlar', 'sil', {'id': id});
  }

  static Future<void> _tamamlaOffline(dynamic id) async {
    final db = await DatabaseHelper.database;
    await db.update('sayimlar', {'durum': 'tamamlandi'}, where: 'id = ?', whereArgs: [id]);

    // Hem temp hem server ID için queue'ya ekle
    // Temp ise: sync sırasında önce ekle çalışır, sonra tamamla çalışır
    await SyncService.kuyruguEkle('sayimlar', 'tamamla', {'id': id});
  }

  static Future<List<Map<String, dynamic>>> _kalemListeleOffline(dynamic sayimId) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('sayim_kalemleri', where: 'sayim_id = ?', whereArgs: [sayimId?.toString()]);

    // Ürün bilgilerini ekle (ekran isletme_urunler nested objesi bekliyor)
    final result = <Map<String, dynamic>>[];
    for (final k in rows) {
      final kalem = Map<String, dynamic>.from(k);
      final urunId = kalem['urun_id']?.toString();
      if (urunId != null && urunId.isNotEmpty) {
        final urunRows = await db.query('urunler', where: 'id = ?', whereArgs: [urunId]);
        if (urunRows.isNotEmpty) {
          final u = urunRows.first;
          // Ekran isletme_urunler nested objesi bekliyor (API formatına uygun)
          kalem['isletme_urunler'] = {
            'id': u['id'],
            'urun_kodu': u['urun_kodu'],
            'urun_adi': u['urun_adi'],
            'isim_2': u['isim_2'],
            'barkodlar': u['barkodlar'],
            'birim': u['birim'],
            'aktif': u['aktif'],
          };
        }
      }
      result.add(kalem);
    }
    return result;
  }

  static Future<Map<String, dynamic>> _kalemEkleOffline(dynamic sayimId, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final tempId = await OfflineIdService.nextId();
    final urunId = data['urun_id']?.toString();
    final row = {
      'id': tempId,
      'sayim_id': sayimId?.toString(),
      'urun_id': urunId,
      'miktar': data['miktar'],
      'birim': data['birim'],
      'notlar': data['notlar'] ?? '',
      'son_guncelleme': DateTime.now().toIso8601String(),
    };
    await db.insert('sayim_kalemleri', row);
    await SyncService.kuyruguEkle('sayim_kalemleri', 'ekle', {
      ...data,
      'sayim_id': sayimId,
      '_temp_id': tempId,
    });

    // Ürün bilgilerini ekle (ekran isletme_urunler nested objesi bekliyor)
    if (urunId != null) {
      final urunRows = await db.query('urunler', where: 'id = ?', whereArgs: [urunId]);
      if (urunRows.isNotEmpty) {
        final u = urunRows.first;
        row['isletme_urunler'] = {
          'id': u['id'],
          'urun_kodu': u['urun_kodu'],
          'urun_adi': u['urun_adi'],
          'isim_2': u['isim_2'],
          'barkodlar': u['barkodlar'],
          'birim': u['birim'],
          'aktif': u['aktif'],
        };
      }
    }
    return row;
  }

  static Future<void> _kalemGuncelleOffline(dynamic sayimId, dynamic kalemId, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final updateData = Map<String, dynamic>.from(data);
    updateData['son_guncelleme'] = DateTime.now().toIso8601String();
    await db.update('sayim_kalemleri', updateData, where: 'id = ?', whereArgs: [kalemId]);

    if (OfflineIdService.isTempId(kalemId)) {
      // Henüz sunucuya gitmemiş
    } else {
      await SyncService.kuyruguEkle('sayim_kalemleri', 'guncelle', {
        ...data,
        'sayim_id': sayimId,
        'id': kalemId,
      });
    }
  }

  static Future<void> _kalemSilOffline(dynamic sayimId, dynamic kalemId) async {
    final db = await DatabaseHelper.database;

    if (OfflineIdService.isTempId(kalemId)) {
      await db.delete('sayim_kalemleri', where: 'id = ?', whereArgs: [kalemId]);
      await SyncService.kuyruguTemizle('sayim_kalemleri', kalemId);
    } else {
      await db.delete('sayim_kalemleri', where: 'id = ?', whereArgs: [kalemId]);
      await SyncService.kuyruguEkle('sayim_kalemleri', 'sil', {
        'sayim_id': sayimId,
        'id': kalemId,
      });
    }
  }

  static Future<Map<String, dynamic>> _toplaOffline({
    required List<String> sayimIdleri,
    required String ad,
    required String isletmeId,
  }) async {
    final db = await DatabaseHelper.database;
    final tempId = await OfflineIdService.nextId();

    // Kaynak sayımların kalemlerini topla ve ürüne göre grupla
    final kalemMap = <dynamic, Map<String, dynamic>>{};
    final kaynakSayimlar = <Map<String, dynamic>>[];

    for (final sayimId in sayimIdleri) {
      final sayimRows = await db.query('sayimlar', where: 'id = ?', whereArgs: [sayimId]);
      if (sayimRows.isNotEmpty) {
        kaynakSayimlar.add(sayimRows.first);
      }

      final kalemler = await db.query('sayim_kalemleri', where: 'sayim_id = ?', whereArgs: [sayimId]);
      for (final k in kalemler) {
        final urunId = k['urun_id'];
        if (kalemMap.containsKey(urunId)) {
          kalemMap[urunId]!['miktar'] = (kalemMap[urunId]!['miktar'] as num) + (k['miktar'] as num);
        } else {
          kalemMap[urunId] = Map<String, dynamic>.from(k);
        }
      }
    }

    // Toplanmış sayım oluştur
    final notlarJson = jsonEncode({
      'toplanan_sayimlar': kaynakSayimlar.map((s) => {
        'id': s['id'],
        'ad': s['ad'],
        'tarih': s['tarih'],
      }).toList(),
    });

    final row = {
      'id': tempId,
      'ad': ad,
      'tarih': DateTime.now().toIso8601String(),
      'durum': 'tamamlandi',
      'isletme_id': isletmeId,
      'depo_id': null,
      'kullanici_id': null,
      'kisiler': '[]',
      'notlar': notlarJson,
      'son_guncelleme': DateTime.now().toIso8601String(),
    };
    await db.insert('sayimlar', row);

    // Toplanmış kalemleri ekle
    for (final entry in kalemMap.entries) {
      final kalemTempId = await OfflineIdService.nextId();
      await db.insert('sayim_kalemleri', {
        'id': kalemTempId,
        'sayim_id': tempId,
        'urun_id': entry.key,
        'miktar': entry.value['miktar'],
        'birim': entry.value['birim'],
        'notlar': '',
        'son_guncelleme': DateTime.now().toIso8601String(),
      });
    }

    await SyncService.kuyruguEkle('sayimlar', 'topla', {
      'sayim_idleri': sayimIdleri,
      'ad': ad,
      'isletme_id': isletmeId,
      '_temp_id': tempId,
    });

    return row;
  }

  static Future<List<Map<String, dynamic>>> _toplanmisListeleOffline(String isletmeId) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('sayimlar',
      where: "isletme_id = ? AND durum != 'silindi'",
      whereArgs: [isletmeId],
      orderBy: 'tarih DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final notlar = row['notlar'] as String?;
      if (notlar == null || notlar.isEmpty) continue;
      try {
        final parsed = jsonDecode(notlar);
        if (parsed is! Map || !parsed.containsKey('toplanan_sayimlar')) continue;
      } catch (_) {
        continue;
      }

      final sayim = Map<String, dynamic>.from(row);
      if (sayim['kisiler'] is String) {
        try {
          sayim['kisiler'] = jsonDecode(sayim['kisiler'] as String);
        } catch (_) {
          sayim['kisiler'] = [];
        }
      }
      result.add(sayim);
    }
    return result;
  }
}

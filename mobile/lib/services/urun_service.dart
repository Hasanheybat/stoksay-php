import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'offline_id_service.dart';
import 'depo_service.dart' show AktifSayimException;
import '../db/database_helper.dart';
import '../db/sync_service.dart';

class UrunService {
  // ── Ana Metodlar (offline/online yönlendirme) ──

  static Future<List<Map<String, dynamic>>> listele(String isletmeId, {int sayfa = 1, int limit = 50, String? arama, String? alan}) async {
    if (StorageService.isOffline) return _listeleOffline(isletmeId, arama: arama);
    return listeleOnline(isletmeId, sayfa: sayfa, limit: limit, arama: arama, alan: alan);
  }

  static Future<Map<String, dynamic>?> barkodBul(String isletmeId, String barkod) async {
    if (StorageService.isOffline) return _barkodBulOffline(isletmeId, barkod);
    return barkodBulOnline(isletmeId, barkod);
  }

  static Future<Map<String, dynamic>> ekle(Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _ekleOffline(data);
    return ekleOnline(data);
  }

  static Future<Map<String, dynamic>> guncelle(dynamic id, Map<String, dynamic> data) async {
    if (StorageService.isOffline) return _guncelleOffline(id, data);
    return guncelleOnline(id, data);
  }

  static Future<void> sil(dynamic id, {String? isletmeId}) async {
    if (StorageService.isOffline) return _silOffline(id);

    // Online: önce SQLite cache'den aktif sayım kontrolü (sayım adlarını bulmak için)
    try {
      final db = await DatabaseHelper.database;
      final aktifSayimlar = await db.rawQuery('''
        SELECT DISTINCT s.ad FROM sayim_kalemleri sk
        JOIN sayimlar s ON s.id = sk.sayim_id
        WHERE sk.urun_id = ? AND s.durum = 'devam'
      ''', [id?.toString()]);
      if (aktifSayimlar.isNotEmpty) {
        final adlar = aktifSayimlar.map((s) => s['ad']?.toString() ?? 'İsimsiz sayım').toList();
        throw AktifSayimException(
          'Bu ürün aktif sayımlarda kullanılıyor.',
          adlar,
        );
      }
    } catch (e) {
      if (e is AktifSayimException) rethrow;
      // SQLite hatası olursa devam et, backend kontrol eder
    }

    try {
      return await silOnline(id);
    } on DioException catch (e) {
      // Backend 409 döndürürse aktif sayım hatası
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        final hata = data is Map ? data['hata']?.toString() ?? '' : '';
        final sayimAdlari = data is Map && data['sayimlar'] is List
            ? (data['sayimlar'] as List).map((s) => s.toString()).toList()
            : <String>[];
        throw AktifSayimException(
          hata.isNotEmpty ? hata : 'Bu ürün aktif sayımlarda kullanılıyor.',
          sayimAdlari,
        );
      }
      rethrow;
    }
  }

  // ── Online Metodlar (API) ──

  static Future<List<Map<String, dynamic>>> listeleOnline(String isletmeId, {int sayfa = 1, int limit = 50, String? arama, String? alan}) async {
    final res = await ApiService.dio.get('/urunler', queryParameters: {
      'isletme_id': isletmeId,
      'sayfa': sayfa,
      'limit': limit,
      if (arama != null && arama.isNotEmpty) 'q': arama,
      if (alan != null && alan.isNotEmpty) 'alan': alan,
    });
    final raw = res.data;
    if (raw is Map && raw['data'] is List) {
      return List<Map<String, dynamic>>.from(raw['data']);
    }
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  static Future<Map<String, dynamic>?> barkodBulOnline(String isletmeId, String barkod) async {
    final res = await ApiService.dio.get('/urunler/barkod/$barkod', queryParameters: {'isletme_id': isletmeId});
    return Map<String, dynamic>.from(res.data);
  }

  static Future<Map<String, dynamic>> ekleOnline(Map<String, dynamic> data) async {
    final res = await ApiService.dio.post('/urunler', data: data);
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {};
  }

  static Future<Map<String, dynamic>> guncelleOnline(dynamic id, Map<String, dynamic> data) async {
    final res = await ApiService.dio.put('/urunler/$id', data: data);
    if (res.data is Map) return Map<String, dynamic>.from(res.data);
    return {};
  }

  static Future<void> silOnline(dynamic id) async {
    await ApiService.dio.delete('/urunler/$id');
  }

  // ── Offline Metodlar (SQLite) ──

  static Future<List<Map<String, dynamic>>> _listeleOffline(String isletmeId, {String? arama}) async {
    final db = await DatabaseHelper.database;
    List<Map<String, dynamic>> rows;
    if (arama != null && arama.isNotEmpty) {
      final q = '%${arama.toLowerCase()}%';
      rows = await db.query('urunler',
        where: 'isletme_id = ? AND aktif = 1 AND (LOWER(urun_adi) LIKE ? OR LOWER(urun_kodu) LIKE ? OR LOWER(barkodlar) LIKE ?)',
        whereArgs: [isletmeId, q, q, q],
      );
    } else {
      rows = await db.query('urunler', where: 'isletme_id = ? AND aktif = 1', whereArgs: [isletmeId]);
    }

    // barkodlar JSON string → List çevir (ekranlar List bekliyor)
    return rows.map((row) {
      final r = Map<String, dynamic>.from(row);
      if (r['barkodlar'] is String) {
        try {
          r['barkodlar'] = jsonDecode(r['barkodlar'] as String);
        } catch (_) {
          r['barkodlar'] = [];
        }
      }
      return r;
    }).toList();
  }

  static Future<Map<String, dynamic>?> _barkodBulOffline(String isletmeId, String barkod) async {
    final db = await DatabaseHelper.database;
    // LIKE wildcard'larını escape et (SQL injection koruması)
    final escapedBarkod = barkod.replaceAll('%', '\\%').replaceAll('_', '\\_');
    final rows = await db.query('urunler',
      where: "isletme_id = ? AND aktif = 1 AND barkodlar LIKE ? ESCAPE '\\'",
      whereArgs: [isletmeId, '%$escapedBarkod%'],
    );
    if (rows.isEmpty) return null;

    // barkodlar JSON string olarak kayıtlı, doğrulama yap
    for (final row in rows) {
      try {
        final barkodlar = jsonDecode(row['barkodlar'] as String? ?? '[]');
        if (barkodlar is List && barkodlar.contains(barkod)) {
          // barkodlar'ı List olarak döndür (ekranlar bunu bekliyor)
          return {...row, 'barkodlar': barkodlar};
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<Map<String, dynamic>> _ekleOffline(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final tempId = await OfflineIdService.nextId();
    final row = {
      'id': tempId,
      'urun_kodu': data['urun_kodu'],
      'urun_adi': data['urun_adi'],
      'isim_2': data['isim_2'],
      'birim': data['birim'],
      'barkodlar': jsonEncode(data['barkodlar'] ?? []),
      'isletme_id': data['isletme_id'],
      'aktif': 1,
      'son_guncelleme': DateTime.now().toIso8601String(),
    };
    await db.insert('urunler', row);
    await SyncService.kuyruguEkle('urunler', 'ekle', {
      ...data,
      '_temp_id': tempId,
    });
    return {...row, 'barkodlar': data['barkodlar'] ?? []};
  }

  static Future<Map<String, dynamic>> _guncelleOffline(dynamic id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.database;
    final updateData = Map<String, dynamic>.from(data);

    // barkodlar: SQLite'ta JSON formatında saklanmalı (_ekleOffline ile tutarlı)
    if (updateData.containsKey('barkodlar')) {
      updateData['barkodlar'] = jsonEncode(updateData['barkodlar'] ?? '');
    }

    updateData['son_guncelleme'] = DateTime.now().toIso8601String();
    await db.update('urunler', updateData, where: 'id = ?', whereArgs: [id]);

    if (OfflineIdService.isTempId(id)) {
      // Henüz sunucuya gitmemiş — sync_queue'daki ekle kaydı zaten var
    } else {
      // Sync kuyruğuna orijinal data gönder (barkodlar comma-string backend formatında)
      await SyncService.kuyruguEkle('urunler', 'guncelle', {'id': id, ...data});
    }

    // Güncel satırı oku ve barkodları decode et (ekranların beklediği format)
    final rows = await db.query('urunler', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return {};
    final result = Map<String, dynamic>.from(rows.first);
    if (result['barkodlar'] is String) {
      try {
        result['barkodlar'] = jsonDecode(result['barkodlar'] as String);
      } catch (_) {
        result['barkodlar'] = [];
      }
    }
    return result;
  }

  static Future<void> _silOffline(dynamic id) async {
    final db = await DatabaseHelper.database;

    // Aktif sayımda kullanılıyor mu kontrol et (backend ile aynı mantık)
    final aktifSayimlar = await db.rawQuery('''
      SELECT DISTINCT s.ad FROM sayim_kalemleri sk
      JOIN sayimlar s ON s.id = sk.sayim_id
      WHERE sk.urun_id = ? AND s.durum = 'devam'
    ''', [id?.toString()]);
    if (aktifSayimlar.isNotEmpty) {
      final adlar = aktifSayimlar.map((s) => s['ad']?.toString() ?? 'İsimsiz sayım').toList();
      throw AktifSayimException(
        'Bu ürün aktif sayımlarda kullanılıyor.',
        adlar,
      );
    }

    // Soft delete (aktif=0) — backend ile aynı mantık
    await db.update('urunler', {'aktif': 0}, where: 'id = ?', whereArgs: [id]);

    if (OfflineIdService.isTempId(id)) {
      // Temp ürün → sync_queue'daki 'ekle' kalır + 'sil' eklenir
      // Online'a dönünce: önce ürün oluşturulur, sonra pasife alınır
      await SyncService.kuyruguEkle('urunler', 'sil', {'id': id, 'urun_adi': ''});
    } else {
      // Sunucu ürünü — silme işlemini kuyruğa ekle
      final rows = await db.query('urunler', where: 'id = ?', whereArgs: [id]);
      final urunAdi = rows.isNotEmpty ? rows.first['urun_adi'] : '';
      await SyncService.kuyruguEkle('urunler', 'sil', {'id': id, 'urun_adi': urunAdi});
    }
  }
}

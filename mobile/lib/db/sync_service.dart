import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/isletme.dart';
import '../services/depo_service.dart';
import '../services/urun_service.dart';
import '../services/sayim_service.dart';
import '../services/storage_service.dart';
import 'database_helper.dart';

/// Senkronizasyon sonucu (push)
class SyncResult {
  final int basarili;
  final int basarisiz;
  final List<String> hatalar;

  const SyncResult({this.basarili = 0, this.basarisiz = 0, this.hatalar = const []});
}

/// İndirme istatistikleri (pull)
class SyncStats {
  int depoSayisi = 0;
  int urunSayisi = 0;
  int sayimSayisi = 0;
  int kalemSayisi = 0;

  @override
  String toString() {
    final parts = <String>[];
    if (urunSayisi > 0) parts.add('$urunSayisi ürün');
    if (depoSayisi > 0) parts.add('$depoSayisi depo');
    if (sayimSayisi > 0) parts.add('$sayimSayisi sayım');
    if (kalemSayisi > 0) parts.add('$kalemSayisi kalem');
    return parts.isEmpty ? 'Veri bulunamadı' : '${parts.join(", ")} indirildi';
  }
}

class SyncService {
  /// Sunucudan tüm verileri çekip SQLite'a yazar.
  /// Offline moddayken negatif ID'li (henüz sync olmamış) satırları korur.
  static Future<SyncStats> tamSenkronizasyon(List<Isletme> isletmeler) async {
    final db = await DatabaseHelper.database;
    final isOffline = StorageService.isOffline;
    final stats = SyncStats();

    // Önce isletmeler tablosuna kaydet
    for (final isletme in isletmeler) {
      await db.insert('isletmeler', {
        'id': isletme.id,
        'ad': isletme.ad,
        'kod': isletme.kod,
        'aktif': isletme.aktif ? 1 : 0,
        'son_guncelleme': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final isletme in isletmeler) {
      final isletmeId = isletme.id; // String UUID

      // Depolar
      try {
        final depolar = await DepoService.listeleOnline(isletmeId);

        if (isOffline) {
          // Temp ID'li satırları sakla
          final localDepolar = await db.query('depolar',
            where: "isletme_id = ? AND id LIKE 'temp_%'",
            whereArgs: [isletmeId]);
          await db.delete('depolar', where: 'isletme_id = ?', whereArgs: [isletmeId]);
          for (final d in depolar) {
            final did = d['id']?.toString() ?? '';
            if (did.isEmpty) continue;
            await db.insert('depolar', {
              'id': did,
              'ad': d['ad'],
              'konum': d['konum'],
              'isletme_id': isletmeId,
              'aktif': _parseAktif(d['aktif']),
              'son_guncelleme': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          // Temp ID'li satırları geri ekle
          for (final d in localDepolar) {
            await db.insert('depolar', d, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } else {
          await db.delete('depolar', where: 'isletme_id = ?', whereArgs: [isletmeId]);
          for (final d in depolar) {
            final did = d['id']?.toString() ?? '';
            if (did.isEmpty) continue;
            await db.insert('depolar', {
              'id': did,
              'ad': d['ad'],
              'konum': d['konum'],
              'isletme_id': isletmeId,
              'aktif': _parseAktif(d['aktif']),
              'son_guncelleme': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        stats.depoSayisi += depolar.length;
      } catch (e) { debugPrint('[Sync] Depo pull hatası: $e'); }

      // Urunler
      try {
        final liste = await UrunService.listeleOnline(isletmeId, sayfa: 1, limit: 10000);

        if (isOffline) {
          final localUrunler = await db.query('urunler',
            where: "isletme_id = ? AND id LIKE 'temp_%'",
            whereArgs: [isletmeId]);
          await db.delete('urunler', where: 'isletme_id = ?', whereArgs: [isletmeId]);
          for (final u in liste) {
            await db.insert('urunler', {
              'id': u['id']?.toString() ?? '',
              'urun_kodu': u['urun_kodu'],
              'urun_adi': u['urun_adi'],
              'isim_2': u['isim_2'],
              'birim': u['birim'],
              'barkodlar': jsonEncode(u['barkodlar'] ?? []),
              'isletme_id': isletmeId,
              'aktif': _parseAktif(u['aktif']),
              'son_guncelleme': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          for (final u in localUrunler) {
            await db.insert('urunler', u, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } else {
          await db.delete('urunler', where: 'isletme_id = ?', whereArgs: [isletmeId]);
          for (final u in liste) {
            await db.insert('urunler', {
              'id': u['id']?.toString() ?? '',
              'urun_kodu': u['urun_kodu'],
              'urun_adi': u['urun_adi'],
              'isim_2': u['isim_2'],
              'birim': u['birim'],
              'barkodlar': jsonEncode(u['barkodlar'] ?? []),
              'isletme_id': isletmeId,
              'aktif': _parseAktif(u['aktif']),
              'son_guncelleme': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
        stats.urunSayisi += liste.length;
      } catch (e) { debugPrint('[Sync] Urun pull hatası: $e'); }

      // Sayimlar
      try {
        final sayimlar = await SayimService.listeleOnline(isletmeId);

        if (isOffline) {
          // Sunucu verilerini sil (temp olanlar hariç)
          await db.delete('sayimlar',
            where: "isletme_id = ? AND id NOT LIKE 'temp_%'",
            whereArgs: [isletmeId]);
          await db.delete('sayim_kalemleri',
            where: "sayim_id NOT LIKE 'temp_%'");
        } else {
          // Online: tüm eski veriyi temizle (sayim_kalemleri dahil)
          final eskiSayimlar = await db.query('sayimlar',
            columns: ['id'], where: 'isletme_id = ?', whereArgs: [isletmeId]);
          for (final s in eskiSayimlar) {
            await db.delete('sayim_kalemleri', where: 'sayim_id = ?', whereArgs: [s['id']]);
          }
          await db.delete('sayimlar', where: 'isletme_id = ?', whereArgs: [isletmeId]);
        }

        for (final s in sayimlar) {
          final sayimId = s['id']?.toString() ?? '';
          final depoAdi = s['depolar'] is Map ? s['depolar']['ad']?.toString() : null;
          await db.insert('sayimlar', {
            'id': sayimId,
            'ad': s['ad'],
            'tarih': s['tarih'],
            'durum': s['durum'],
            'isletme_id': isletmeId,
            'depo_id': s['depo_id']?.toString(),
            'depo_adi': depoAdi,
            'kullanici_id': s['kullanici_id']?.toString(),
            'kisiler': jsonEncode(s['kisiler'] ?? []),
            'notlar': s['notlar'],
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          // Kalemler
          try {
            final kalemler = await SayimService.kalemListeleOnline(sayimId);
            await _kalemlerKaydet(db, kalemler, sayimId, isletmeId);
            stats.kalemSayisi += kalemler.length;
          } catch (e) { debugPrint('[Sync] Kalem pull hatası ($sayimId): $e'); }
        }
        stats.sayimSayisi += sayimlar.length;
      } catch (e) { debugPrint('[Sync] Sayim pull hatası: $e'); }

      // Toplanmış sayımlar (toplama=1 ile ayrıca çekilir)
      try {
        final toplanmislar = await SayimService.toplanmisListeleOnline(isletmeId);
        for (final s in toplanmislar) {
          final sayimId = s['id']?.toString() ?? '';
          // Zaten silinmişse (offline temp) atla
          final mevcut = await db.query('sayimlar', where: 'id = ?', whereArgs: [sayimId]);
          if (mevcut.isNotEmpty) continue; // Normal sync'te zaten eklenmişse atla

          final topDepoAdi = s['depolar'] is Map ? s['depolar']['ad']?.toString() : null;
          await db.insert('sayimlar', {
            'id': sayimId,
            'ad': s['ad'],
            'tarih': s['tarih'],
            'durum': s['durum'],
            'isletme_id': isletmeId,
            'depo_id': s['depo_id']?.toString(),
            'depo_adi': topDepoAdi,
            'kullanici_id': s['kullanici_id']?.toString(),
            'kisiler': jsonEncode(s['kisiler'] ?? []),
            'notlar': s['notlar'],
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          // Toplanmış sayımın kalemlerini de indir
          try {
            final kalemler = await SayimService.kalemListeleOnline(sayimId);
            await _kalemlerKaydet(db, kalemler, sayimId, isletmeId);
            stats.kalemSayisi += kalemler.length;
          } catch (e) { debugPrint('[Sync] Kalem pull hatası ($sayimId): $e'); }
        }
        stats.sayimSayisi += toplanmislar.length;
      } catch (e) { debugPrint('[Sync] Toplanmis pull hatası: $e'); }
    }

    return stats;
  }

  /// Kalem listesini SQLite'a kaydet + pasif ürünleri de ekle
  static Future<void> _kalemlerKaydet(Database db, List<Map<String, dynamic>> kalemler, String sayimId, String isletmeId) async {
    for (final k in kalemler) {
      await db.insert('sayim_kalemleri', {
        'id': k['id']?.toString() ?? '',
        'sayim_id': sayimId,
        'urun_id': k['urun_id']?.toString(),
        'miktar': k['miktar'],
        'birim': k['birim'],
        'notlar': k['notlar'],
        'son_guncelleme': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Pasif ürünleri de SQLite'a kaydet (sayımda referans olarak kalması için)
      final urun = k['isletme_urunler'];
      if (urun is Map && urun['id'] != null) {
        final urunId = urun['id'].toString();
        final mevcut = await db.query('urunler', where: 'id = ?', whereArgs: [urunId]);
        if (mevcut.isEmpty) {
          await db.insert('urunler', {
            'id': urunId,
            'urun_kodu': urun['urun_kodu'],
            'urun_adi': urun['urun_adi'],
            'isim_2': urun['isim_2'],
            'birim': urun['birim'],
            'barkodlar': jsonEncode(urun['barkodlar'] ?? []),
            'isletme_id': isletmeId,
            'aktif': _parseAktif(urun['aktif']),
            'son_guncelleme': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
  }

  /// aktif alanını güvenli şekilde 0/1'e çevir (bool, int, string hepsi olabilir)
  /// API zaten aktif=1 olanları döndürüyor, field yoksa default 1
  static int _parseAktif(dynamic value) {
    if (value == null) return 1; // API filtreli döndürüyor, yoksa aktif kabul et
    if (value == false || value == 0 || value == '0') return 0;
    return 1;
  }

  /// Sync kuyruğundaki bekleyen işlemleri sunucuya gönderir.
  /// Temp ID eşleme ile referansları günceller.
  static Future<SyncResult> kuyruguGonder() async {
    final db = await DatabaseHelper.database;

    // 3+ kez basarisiz olan kayitlari temizle
    await db.delete('sync_queue', where: 'hata_sayisi >= 3');

    final bekleyenler = await db.query(
      'sync_queue',
      where: "durum IN ('bekliyor', 'hata')",
      orderBy: 'id ASC',
    );

    int basarili = 0;
    int basarisiz = 0;
    final hatalar = <String>[];

    // Temp ID → Server ID eşleme tablosu
    final tempIdMap = <dynamic, dynamic>{};

    for (final item in bekleyenler) {
      final id = item['id'] as int;
      final tablo = item['tablo'] as String;
      final islem = item['islem'] as String;
      final veri = Map<String, dynamic>.from(jsonDecode(item['veri'] as String));

      // Temp ID'leri gerçek ID'lerle değiştir
      _resolveIds(veri, tempIdMap);

      await db.update('sync_queue', {'durum': 'gonderiliyor'}, where: 'id = ?', whereArgs: [id]);

      final aciklama = _islemAciklamasi(tablo, islem, veri);

      try {
        // API çağrısı + local DB güncelleme
        dynamic apiResult;
        String? tempId;

        switch (tablo) {
          case 'depolar':
            if (islem == 'ekle') {
              apiResult = await DepoService.ekleOnline(veri['isletme_id'], veri['ad'], konum: veri['konum']);
              tempId = veri['_temp_id']?.toString();
            } else if (islem == 'guncelle') {
              await DepoService.guncelleOnline(veri['id'], veri);
            } else if (islem == 'sil') {
              await DepoService.silOnline(veri['id']);
            }
            break;

          case 'urunler':
            if (islem == 'ekle') {
              apiResult = await UrunService.ekleOnline(veri);
              tempId = veri['_temp_id']?.toString();
            } else if (islem == 'guncelle') {
              await UrunService.guncelleOnline(veri['id'], veri);
            } else if (islem == 'sil') {
              await UrunService.silOnline(veri['id']);
            }
            break;

          case 'sayimlar':
            if (islem == 'ekle') {
              apiResult = await SayimService.olusturOnline(veri);
              tempId = veri['_temp_id']?.toString();
            } else if (islem == 'guncelle') {
              await SayimService.guncelleOnline(veri['id'], veri);
            } else if (islem == 'sil') {
              await SayimService.silOnline(veri['id']);
            } else if (islem == 'tamamla') {
              await SayimService.tamamlaOnline(veri['id']);
            } else if (islem == 'topla') {
              apiResult = await SayimService.toplaOnline(
                sayimIdleri: List<String>.from(veri['sayim_idleri']),
                ad: veri['ad'],
                isletmeId: veri['isletme_id'],
              );
              tempId = veri['_temp_id']?.toString();
            }
            break;

          case 'sayim_kalemleri':
            if (islem == 'ekle') {
              apiResult = await SayimService.kalemEkleOnline(veri['sayim_id'], veri);
              tempId = veri['_temp_id']?.toString();
            } else if (islem == 'guncelle') {
              await SayimService.kalemGuncelleOnline(veri['sayim_id'], veri['id'], veri);
            } else if (islem == 'sil') {
              await SayimService.kalemSilOnline(veri['sayim_id'], veri['id']);
            }
            break;
        }

        // Local DB güncellemelerini transaction ile yap (atomik)
        await db.transaction((txn) async {
          if (tempId != null && apiResult is Map && apiResult['id'] != null) {
            final realId = apiResult['id'];
            tempIdMap[tempId] = realId;
            if (tablo == 'depolar') {
              await txn.update('depolar', {'id': realId}, where: 'id = ?', whereArgs: [tempId]);
            } else if (tablo == 'urunler') {
              await txn.update('urunler', {'id': realId}, where: 'id = ?', whereArgs: [tempId]);
              await txn.update('sayim_kalemleri', {'urun_id': realId}, where: 'urun_id = ?', whereArgs: [tempId]);
            } else if (tablo == 'sayimlar') {
              await txn.update('sayimlar', {'id': realId}, where: 'id = ?', whereArgs: [tempId]);
              await txn.update('sayim_kalemleri', {'sayim_id': realId}, where: 'sayim_id = ?', whereArgs: [tempId]);
            } else if (tablo == 'sayim_kalemleri') {
              await txn.update('sayim_kalemleri', {'id': realId}, where: 'id = ?', whereArgs: [tempId]);
            }
          }
          await txn.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        });

        // Queue refs güncelle (transaction dışı — diğer queue item'ları)
        if (tempId != null && apiResult is Map && apiResult['id'] != null) {
          await _updateQueueRefs(db, tempId, apiResult['id']);
        }
        basarili++;
      } catch (e) {
        await db.rawUpdate('UPDATE sync_queue SET durum = ?, hata_sayisi = hata_sayisi + 1 WHERE id = ?', ['hata', id]);
        basarisiz++;
        hatalar.add('$aciklama: ${_hataAciklamasi(e)}');
      }
    }

    return SyncResult(basarili: basarili, basarisiz: basarisiz, hatalar: hatalar);
  }

  /// Temp ID → gerçek ID dönüşümünü queue'daki bekleyen kayıtlara da yansıtır.
  /// Böylece bir sonraki sync çalıştığında tempIdMap boş olsa bile doğru ID kullanılır.
  static Future<void> _updateQueueRefs(Database db, dynamic tempId, dynamic realId) async {
    final bekleyenler = await db.query('sync_queue',
      where: "durum IN ('bekliyor', 'hata', 'gonderiliyor')",
    );
    for (final item in bekleyenler) {
      final veriStr = item['veri'] as String;
      if (!veriStr.contains(tempId.toString())) continue;

      final veri = Map<String, dynamic>.from(jsonDecode(veriStr));
      bool degisti = false;
      for (final key in ['id', 'sayim_id', 'urun_id', 'depo_id']) {
        if (veri[key]?.toString() == tempId.toString()) {
          veri[key] = realId;
          degisti = true;
        }
      }
      if (veri.containsKey('sayim_idleri')) {
        final liste = (veri['sayim_idleri'] as List);
        for (int i = 0; i < liste.length; i++) {
          if (liste[i]?.toString() == tempId.toString()) {
            liste[i] = realId;
            degisti = true;
          }
        }
      }
      if (degisti) {
        await db.update('sync_queue', {'veri': jsonEncode(veri)},
          where: 'id = ?', whereArgs: [item['id']]);
      }
    }
  }

  /// Veri içindeki temp ID referanslarını gerçek ID'lerle değiştirir
  static void _resolveIds(Map<String, dynamic> veri, Map<dynamic, dynamic> tempIdMap) {
    for (final key in ['id', 'sayim_id', 'urun_id', 'depo_id', 'isletme_id']) {
      if (veri.containsKey(key) && tempIdMap.containsKey(veri[key])) {
        veri[key] = tempIdMap[veri[key]];
      }
    }
    // sayim_idleri listesi (topla işlemi için)
    if (veri.containsKey('sayim_idleri')) {
      veri['sayim_idleri'] = (veri['sayim_idleri'] as List).map((id) => tempIdMap[id] ?? id).toList();
    }
  }

  /// İşlem için okunabilir açıklama oluşturur
  static String _islemAciklamasi(String tablo, String islem, Map<String, dynamic> veri) {
    final ad = veri['ad'] ?? veri['urun_adi'] ?? veri['_temp_id']?.toString() ?? '';
    final islemAd = switch (islem) {
      'ekle' => 'ekleme',
      'guncelle' => 'güncelleme',
      'sil' => 'silme',
      'tamamla' => 'tamamlama',
      'topla' => 'toplama',
      _ => islem,
    };
    final tabloAd = switch (tablo) {
      'depolar' => 'Depo',
      'urunler' => 'Ürün',
      'sayimlar' => 'Sayım',
      'sayim_kalemleri' => 'Kalem',
      _ => tablo,
    };
    return '$tabloAd $islemAd${ad.isNotEmpty ? " ($ad)" : ""}';
  }

  /// Hata mesajını okunabilir hale getirir
  static String _hataAciklamasi(dynamic e) {
    final msg = e.toString();
    if (msg.contains('aktif bir sayımda')) return 'Aktif sayımda kullanılıyor';
    if (msg.contains('409')) return 'Çakışma';
    if (msg.contains('404')) return 'Bulunamadı';
    if (msg.contains('500')) return 'Sunucu hatası';
    return 'Hata';
  }

  static Future<void> kuyruguEkle(String tablo, String islem, Map<String, dynamic> veri) async {
    final db = await DatabaseHelper.database;
    await db.insert('sync_queue', {
      'tablo': tablo,
      'islem': islem,
      'veri': jsonEncode(veri),
      'olusturma': DateTime.now().toIso8601String(),
      'durum': 'bekliyor',
    });
  }

  /// Negatif ID'ye ait sync_queue kaydını sil (offline'da oluşturup silinen öğe)
  static Future<void> kuyruguTemizle(String tablo, dynamic tempId) async {
    final db = await DatabaseHelper.database;
    final idStr = tempId.toString();
    final rows = await db.query('sync_queue', where: "tablo = ?", whereArgs: [tablo]);
    for (final row in rows) {
      try {
        final veri = Map<String, dynamic>.from(jsonDecode(row['veri'] as String));
        if (veri['_temp_id']?.toString() == idStr) {
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (e) { debugPrint('[Sync] Queue temizle parse hatası: $e'); }
    }
  }

  /// Bir sayıma ait tüm kalem queue kayıtlarını temizle (sayım silinince çağrılır)
  static Future<void> kuyruguTemizleSayimKalemleri(dynamic sayimId) async {
    final db = await DatabaseHelper.database;
    final idStr = sayimId.toString();
    // sayim_kalemleri queue kayıtlarını temizle
    final rows = await db.query('sync_queue', where: "tablo = 'sayim_kalemleri'");
    for (final row in rows) {
      try {
        final veri = Map<String, dynamic>.from(jsonDecode(row['veri'] as String));
        if (veri['sayim_id']?.toString() == idStr) {
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (e) { debugPrint('[Sync] Kalem queue parse hatası: $e'); }
    }
    // Sayımla ilgili tamamla/guncelle/sil queue kayıtlarını da temizle
    final sayimRows = await db.query('sync_queue', where: "tablo = 'sayimlar'");
    for (final row in sayimRows) {
      try {
        final veri = Map<String, dynamic>.from(jsonDecode(row['veri'] as String));
        if (veri['id']?.toString() == idStr) {
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (e) { debugPrint('[Sync] Sayim queue parse hatası: $e'); }
    }
  }

  /// Online'a dönerken kalan tüm queue kayıtlarını temizle
  /// (başarısızlar kullanıcıya gösterildi, artık gereksiz)
  static Future<void> kuyruguBosalt() async {
    final db = await DatabaseHelper.database;
    await db.delete('sync_queue');
  }

  static Future<int> bekleyenSayisi() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery("SELECT COUNT(*) as c FROM sync_queue WHERE durum IN ('bekliyor','hata')");
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

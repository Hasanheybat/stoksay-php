import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'stoksay.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1→v2: INTEGER ID'ler TEXT'e dönüştü (UUID desteği)
          await db.execute('DROP TABLE IF EXISTS isletmeler');
          await db.execute('DROP TABLE IF EXISTS depolar');
          await db.execute('DROP TABLE IF EXISTS urunler');
          await db.execute('DROP TABLE IF EXISTS sayimlar');
          await db.execute('DROP TABLE IF EXISTS sayim_kalemleri');
          await db.execute('DROP TABLE IF EXISTS kullanici_cache');
          await db.execute('DROP TABLE IF EXISTS sync_queue');
          await _createTables(db);
        }
        if (oldVersion < 3) {
          // v2→v3: sayimlar'a depo_adi eklendi, urunler'den kategori silindi
          try { await db.execute('ALTER TABLE sayimlar ADD COLUMN depo_adi TEXT'); } catch (_) {}
        }
        if (oldVersion < 4) {
          // v3→v4: sync_queue'ya hata_sayisi eklendi
          try { await db.execute('ALTER TABLE sync_queue ADD COLUMN hata_sayisi INTEGER DEFAULT 0'); } catch (_) {}
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE isletmeler (
        id TEXT PRIMARY KEY,
        ad TEXT NOT NULL,
        kod TEXT,
        aktif INTEGER DEFAULT 1,
        son_guncelleme TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE depolar (
        id TEXT PRIMARY KEY,
        ad TEXT NOT NULL,
        konum TEXT,
        isletme_id TEXT,
        aktif INTEGER DEFAULT 1,
        son_guncelleme TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_depolar_isletme ON depolar(isletme_id)');

    await db.execute('''
      CREATE TABLE urunler (
        id TEXT PRIMARY KEY,
        urun_kodu TEXT,
        urun_adi TEXT NOT NULL,
        isim_2 TEXT,
        birim TEXT,
        barkodlar TEXT,
        isletme_id TEXT,
        aktif INTEGER DEFAULT 1,
        son_guncelleme TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_urunler_isletme ON urunler(isletme_id)');

    await db.execute('''
      CREATE TABLE sayimlar (
        id TEXT PRIMARY KEY,
        ad TEXT NOT NULL,
        tarih TEXT,
        durum TEXT DEFAULT 'devam',
        isletme_id TEXT,
        depo_id TEXT,
        depo_adi TEXT,
        kullanici_id TEXT,
        kisiler TEXT,
        notlar TEXT,
        son_guncelleme TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_sayimlar_isletme ON sayimlar(isletme_id)');

    await db.execute('''
      CREATE TABLE sayim_kalemleri (
        id TEXT PRIMARY KEY,
        sayim_id TEXT,
        urun_id TEXT,
        miktar REAL,
        birim TEXT,
        notlar TEXT,
        son_guncelleme TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_kalemler_sayim ON sayim_kalemleri(sayim_id)');

    await db.execute('''
      CREATE TABLE kullanici_cache (
        id TEXT PRIMARY KEY,
        kullanici TEXT,
        yetkiler_map TEXT,
        son_guncelleme TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tablo TEXT NOT NULL,
        islem TEXT NOT NULL,
        veri TEXT NOT NULL,
        olusturma TEXT NOT NULL,
        durum TEXT DEFAULT 'bekliyor',
        hata_sayisi INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_sync_durum ON sync_queue(durum)');
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('isletmeler');
    await db.delete('depolar');
    await db.delete('urunler');
    await db.delete('sayimlar');
    await db.delete('sayim_kalemleri');
    await db.delete('kullanici_cache');
    await db.delete('sync_queue');
  }
}

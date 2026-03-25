# StokSay PHP — Depo Sayim Sistemi

Depo ve stok sayim yonetim sistemi. PHP backend + React admin paneli + Flutter mobil uygulama.

## Sistem Mimarisi

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  React Admin     │────▶│   PHP Backend     │◀────│  Flutter     │
│  Panel (SPA)     │     │   REST API        │     │  Mobil App   │
│  /admin/*        │     │   /api/*          │     │  iOS/Android │
└─────────────────┘     └────────┬───────────┘     └─────────────┘
                                 │
                        ┌────────▼───────────┐
                        │   MySQL / MariaDB   │
                        │   Veritabani        │
                        └─────────────────────┘
```

## Gereksinimler

- PHP 7.4+ (8.x onerilir)
- MySQL 8.0+ veya MariaDB 10.5+
- Composer (bagimliliklari kurmak icin)
- Apache + mod_rewrite (shared hosting'de hazir gelir)
- Node.js 18+ (sadece test icin, production'da gerekmez)

## Hizli Kurulum (5 Adim)

### Adim 1: Veritabani Olustur

cPanel'de veya MySQL komut satirindan:

```sql
CREATE DATABASE stoksay CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'stoksay_user'@'localhost' IDENTIFIED BY 'GUCLU_SIFRE_BURAYA';
GRANT ALL PRIVILEGES ON stoksay.* TO 'stoksay_user'@'localhost';
FLUSH PRIVILEGES;
```

### Adim 2: Tablolari Olustur

`database/schema.sql` dosyasini calistirin:

```bash
mysql -u stoksay_user -p stoksay < database/schema.sql
```

veya cPanel > phpMyAdmin > SQL sekmesi > dosyayi yapistirin.

### Adim 3: Admin Kullanici Olustur

```bash
mysql -u stoksay_user -p stoksay < database/seed.sql
```

Bu komut su kayitlari olusturur:
- Admin: `admin@stoksay.com` / `Admin1234!`
- 3 sistem rolu: Tam Yetkili, Sayimci, Goruntuleici

### Adim 4: Konfigurasyonu Ayarla

`config/config.example.php` dosyasini `config/config.php` olarak kopyalayin:

```bash
cp config/config.example.php config/config.php
```

`config/config.php` dosyasini duzenleyin:

```php
return [
    'db_host'     => 'localhost',
    'db_port'     => 3306,
    'db_name'     => 'stoksay',           // Olusturdgunuz DB adi
    'db_user'     => 'stoksay_user',      // DB kullanicisi
    'db_pass'     => 'GUCLU_SIFRE',       // DB sifresi

    'jwt_secret'  => 'EN_AZ_32_KARAKTER_RASTGELE_BIR_ANAHTAR_BURAYA_YAZIN_1234567890',

    'allowed_origins' => ['https://sizindomain.com'],
];
```

**JWT Secret olusturmak icin:**
```bash
openssl rand -hex 64
```

### Adim 5: Composer Bagimliliklari Kur

```bash
composer install
```

SSH yoksa: Lokal bilgisayarinizda `composer install` yapin, `vendor/` klasorunu sunucuya yukleyin.

## Dosya Yapisi ve Nereye Yuklenir

### Shared Hosting (cPanel) Yukleme

```
/home/kullanici/
├── stoksay/                    ← public_html DISINDA (guvenli)
│   ├── config/
│   │   └── config.php          ← DB bilgileri, JWT secret
│   ├── middleware/              ← Auth, yetki kontrol
│   ├── routes/                  ← API route dosyalari
│   ├── lib/                     ← Router, helpers
│   ├── vendor/                  ← Composer paketleri
│   └── database/                ← SQL dosyalari
│
└── public_html/                ← Web root (Apache)
    ├── index.html              ← React SPA
    ├── assets/                 ← React JS/CSS dosyalari
    ├── .htaccess               ← SPA routing
    ├── .user.ini               ← PHP ayarlari
    └── api/
        ├── index.php           ← API giris noktasi
        └── .htaccess           ← URL rewrite
```

**Onemli:** `config/`, `middleware/`, `routes/`, `lib/`, `vendor/` klasorleri `public_html` DISINDA olmali. Tarayicidan erisilemez olmali.

### api/index.php Duzenleme

`public/api/index.php` dosyasindaki backend yolunu guncellemeniz gerekebilir:

```php
$backendDir = '/home/kullanici/stoksay';  // Gercek yolunuzu yazin
```

Varsayilan olarak `dirname(dirname(__DIR__))` kullanir (2 ust dizin).

## React Admin Panel Kurulumu

Admin paneli zaten build edilmis olarak `public/` klasorunde gelir. Eger kendiniz build etmek isterseniz:

```bash
cd frontend
npm install
npm run build
```

`dist/` klasorunun icindeki tum dosyalari `public_html/` klasorune kopyalayin.

## Mobil Uygulama (Flutter) Baglama

### API URL Ayari

`mobile/lib/config/api_config.dart` dosyasini duzenleyin:

```dart
class ApiConfig {
  // Development (lokal test)
  static const String _devUrl = 'http://10.0.2.2:8888/api';  // Android emulator
  // static const String _devUrl = 'http://localhost:8888/api'; // iOS simulator

  // Production (canli sunucu)
  static const String _prodUrl = 'https://sizindomain.com/api';

  // Hangi URL kullanilacak
  static const bool isProduction = true;  // true yapinca _prodUrl kullanilir

  static String get baseUrl => isProduction ? _prodUrl : _devUrl;

  // Timeout sureleri (milisaniye)
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 10000;
}
```

### Mobil Uygulamayi Derleme

```bash
cd mobile

# Bagimliliklari kur
flutter pub get

# Android APK
flutter build apk --release

# iOS (Mac gerekir)
flutter build ios --release
```

### Mobil Ozellikleri

- Barkod tarama (kamera)
- Offline mod (internet olmadan calismaya devam)
- Online/Offline senkronizasyon
- PDF ve Excel export
- Push bildirimler

### Mobil-Backend Iletisim

Mobil uygulama su endpoint'leri kullanir:

```
POST   /api/auth/login              ← Giris
GET    /api/auth/me                 ← Kullanici bilgisi + yetkiler
GET    /api/profil/isletmelerim     ← Isletme secimi
GET    /api/profil/stats            ← Ana sayfa istatistik
GET    /api/depolar?isletme_id=X    ← Depo listesi
GET    /api/urunler?isletme_id=X    ← Urun listesi (sayfalama)
GET    /api/urunler/barkod/:kod     ← Barkod ile urun ara
POST   /api/urunler                 ← Yeni urun ekle
PUT    /api/urunler/:id             ← Urun guncelle
GET    /api/sayimlar?isletme_id=X   ← Sayim listesi
POST   /api/sayimlar                ← Yeni sayim baslat
GET    /api/sayimlar/:id            ← Sayim detay + kalemler
POST   /api/sayimlar/:id/kalem      ← Kalem ekle
PUT    /api/sayimlar/:id/kalem/:kid ← Kalem guncelle
DELETE /api/sayimlar/:id/kalem/:kid ← Kalem sil
PUT    /api/sayimlar/:id/tamamla    ← Sayimi tamamla
POST   /api/sayimlar/topla          ← Sayimlari birlestir
PUT    /api/profil/ayarlar          ← Kullanici ayarlari
PUT    /api/auth/update-password    ← Sifre degistir
```

## Tum API Endpoint'leri

### Auth (Kimlik Dogrulama)

| Method | Endpoint | Yetki | Aciklama |
|--------|----------|-------|----------|
| POST | `/api/auth/login` | Herkese acik | Email + sifre → JWT token |
| GET | `/api/auth/me` | Token | Kullanici bilgisi + yetkiler |
| PUT | `/api/auth/update-password` | Token | Sifre degistir |
| PUT | `/api/auth/update-email` | Token | Email degistir |

### Isletmeler (Admin)

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/isletmeler` | Liste (sayfalama + arama) |
| GET | `/api/isletmeler/:id` | Detay |
| POST | `/api/isletmeler` | Olustur |
| PUT | `/api/isletmeler/:id` | Guncelle |
| DELETE | `/api/isletmeler/:id` | Pasife al |
| PUT | `/api/isletmeler/:id/restore` | Geri al |

### Depolar

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/depolar` | Liste (isletme_id gerekli) |
| GET | `/api/depolar/:id` | Detay |
| POST | `/api/depolar` | Olustur |
| PUT | `/api/depolar/:id` | Guncelle |
| DELETE | `/api/depolar/:id` | Pasife al |

### Urunler

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/urunler` | Liste (sayfalama) |
| GET | `/api/urunler/:id` | Detay |
| GET | `/api/urunler/barkod/:barkod` | Barkod ile ara |
| POST | `/api/urunler` | Olustur |
| PUT | `/api/urunler/:id` | Guncelle |
| DELETE | `/api/urunler/:id` | Pasife al |
| POST | `/api/urunler/:id/barkod` | Barkod ekle |
| DELETE | `/api/urunler/:id/barkod/:barkod` | Barkod sil |
| POST | `/api/urunler/yukle` | Excel toplu import |
| GET | `/api/urunler/sablon` | Excel sablon indir |

### Sayimlar

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/sayimlar` | Liste |
| GET | `/api/sayimlar/:id` | Detay + kalemler |
| POST | `/api/sayimlar` | Yeni sayim baslat |
| PUT | `/api/sayimlar/:id` | Guncelle |
| DELETE | `/api/sayimlar/:id` | Sil |
| PUT | `/api/sayimlar/:id/tamamla` | Tamamla |
| POST | `/api/sayimlar/:id/kalem` | Kalem ekle |
| PUT | `/api/sayimlar/:id/kalem/:kid` | Kalem guncelle |
| DELETE | `/api/sayimlar/:id/kalem/:kid` | Kalem sil |
| POST | `/api/sayimlar/topla` | Sayimlari birlestir |

### Kullanicilar (Admin)

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/kullanicilar` | Liste |
| GET | `/api/kullanicilar/:id` | Detay + isletme yetkileri |
| POST | `/api/kullanicilar` | Olustur |
| PUT | `/api/kullanicilar/:id` | Guncelle |
| DELETE | `/api/kullanicilar/:id` | Pasife al |
| POST | `/api/kullanicilar/:id/isletme` | Isletme ata |
| DELETE | `/api/kullanicilar/:id/isletme/:iid` | Isletme kaldir |
| GET | `/api/kullanicilar/:id/yetkiler` | Yetki sorgula |
| PUT | `/api/kullanicilar/:id/yetkiler` | Yetki guncelle |

### Roller (Admin)

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/roller` | Liste |
| POST | `/api/roller` | Olustur |
| PUT | `/api/roller/:id` | Guncelle |
| DELETE | `/api/roller/:id` | Sil |

### Profil

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/profil/isletmelerim` | Kullanicinin isletmeleri |
| GET | `/api/profil/stats` | Kisisel istatistikler |
| PUT | `/api/profil/ayarlar` | Ayarlari guncelle |

### Stats (Admin)

| Method | Endpoint | Aciklama |
|--------|----------|----------|
| GET | `/api/stats` | Dashboard sayilari |
| GET | `/api/stats/sayim-trend` | Son 6 ay trend |
| GET | `/api/stats/isletme-sayimlar` | Isletme bazli dagilim |
| GET | `/api/stats/son-sayimlar` | Son 5 sayim |

## Yetki Sistemi

Her kullanici, her isletme icin ayri yetkilere sahiptir:

```json
{
  "urun":         { "goruntule": true, "ekle": true, "duzenle": false, "sil": false },
  "depo":         { "goruntule": true, "ekle": false, "duzenle": false, "sil": false },
  "sayim":        { "goruntule": true, "ekle": true, "duzenle": true, "sil": false },
  "toplam_sayim": { "goruntule": false, "ekle": false, "duzenle": false, "sil": false }
}
```

4 kategori x 4 islem = 16 ayri yetki. Admin kullanicilar tum yetkilere otomatik sahiptir.

## Lokal Gelistirme

```bash
# PHP backend'i baslat (development server)
php -S localhost:8888 -t public server.php

# Tarayicidan ac
open http://localhost:8888
```

## Test

```bash
# API testi (96 test)
node tests/api-test.js http://localhost:8888

# Mobil API uyumluluk testi (27 test)
node tests/mobile-api-test.js http://localhost:8888

# Stres testi (51 test)
node tests/stress-test.js http://localhost:8888

# Guvenlik testi (48 test)
node tests/security-stress-test.js http://localhost:8888
```

## Guvenlik

- JWT kimlik dogrulama (24 saat gecerli)
- Bcrypt sifre hashleme
- SQL injection korumasai (PDO parametrize sorgular)
- XSS korumasai (JSON API, HTML render yok)
- CORS whitelist
- Rate limiting (brute-force korumasi)
- Guvenlik header'lari (X-Frame-Options, CSP, nosniff)
- Soft delete (veri kaybi onleme)
- Yetki bazli erisim kontrolu (IDOR korumasi)
- Transaction + FOR UPDATE (race condition korumasi)

## Lisans

MIT

# StokSay Mobil — Depo Sayim ve Stok Yonetim Uygulamasi

Flutter ile gelistirilmis, offline-first mimari ile calisan mobil depo sayim uygulamasi. iOS ve Android icin tek codebase.

**v4.1.2** — Guvenlik Denetimi + Penetrasyon Testi (Mart 2026)

---

## Teknoloji

| Bilesen | Teknoloji |
|---------|-----------|
| Framework | Flutter 3.11 (Dart) |
| State Management | Riverpod |
| Yerel Veritabani | SQLite (sqflite) |
| API Iletisimi | Dio |
| Token Saklama | FlutterSecureStorage |
| Barkod Tarama | mobile_scanner |
| Excel Export | excel paketi |
| PDF Export | pdf + printing |

---

## Uygulama Yapisi

```
mobile/
├── lib/
│   ├── config/
│   │   └── api_config.dart       # API URL konfigurasyonu
│   ├── db/
│   │   ├── database_helper.dart  # SQLite veritabani yonetimi
│   │   └── sync_service.dart     # Offline senkronizasyon servisi
│   ├── models/                   # Veri modelleri
│   ├── providers/
│   │   ├── auth_provider.dart        # Kimlik dogrulama state
│   │   ├── connectivity_provider.dart # Baglanti durumu
│   │   └── isletme_provider.dart     # Isletme secimi state
│   ├── screens/
│   │   ├── login_screen.dart             # Giris ekrani
│   │   ├── home_screen.dart              # Ana sayfa (dashboard)
│   │   ├── shell_screen.dart             # Alt navigasyon shell
│   │   ├── app_layout.dart               # Uygulama layout
│   │   ├── sayimlar_screen.dart          # Sayim listesi
│   │   ├── sayim_detay_screen.dart       # Sayim detay + kalem ekleme
│   │   ├── yeni_sayim_screen.dart        # Yeni sayim olusturma
│   │   ├── toplanmis_sayimlar_screen.dart # Birlestirilmis sayimlar
│   │   ├── stoklar_screen.dart           # Urun/stok listesi
│   │   ├── urun_ekle_screen.dart         # Yeni urun ekleme
│   │   ├── depolar_screen.dart           # Depo listesi
│   │   └── ayarlar_screen.dart           # Kullanici ayarlari
│   ├── services/
│   │   ├── api_service.dart          # Dio HTTP istemcisi
│   │   ├── auth_service.dart         # Login/logout islemleri
│   │   ├── storage_service.dart      # Token saklama (FlutterSecureStorage)
│   │   ├── offline_id_service.dart   # Guvenli offline ID uretimi
│   │   ├── sayim_service.dart        # Sayim API islemleri
│   │   ├── urun_service.dart         # Urun API islemleri
│   │   ├── depo_service.dart         # Depo API islemleri
│   │   ├── isletme_service.dart      # Isletme API islemleri
│   │   └── profil_service.dart       # Profil API islemleri
│   ├── utils/                    # Yardimci fonksiyonlar
│   ├── widgets/                  # Paylasilan widget'lar
│   └── main.dart                 # Uygulama giris noktasi
├── ios/                          # iOS platform konfigurasyonu
├── android/                      # Android platform konfigurasyonu
└── pubspec.yaml                  # Dart bagimliliklari
```

---

## Ekranlar (12 adet)

| Ekran | Dosya | Aciklama |
|-------|-------|----------|
| Giris | `login_screen.dart` | Email + sifre, client-side dogrulama |
| Ana Sayfa | `home_screen.dart` | Dashboard istatistikleri |
| Sayimlar | `sayimlar_screen.dart` | Sayim listesi, filtreleme, arama |
| Sayim Detay | `sayim_detay_screen.dart` | Kalem ekleme, barkod tarama, miktar |
| Yeni Sayim | `yeni_sayim_screen.dart` | Sayim olusturma formu |
| Birlestirilmis | `toplanmis_sayimlar_screen.dart` | Toplanan sayim raporlari |
| Stoklar | `stoklar_screen.dart` | Urun katalogu |
| Urun Ekle | `urun_ekle_screen.dart` | Yeni urun formu + barkod |
| Depolar | `depolar_screen.dart` | Depo listesi |
| Ayarlar | `ayarlar_screen.dart` | Sifre degistirme, profil |
| Pasif Kullanici | (auth_provider) | Dark ekran + uyari |
| Yetkisiz | (auth_provider) | Dark ekran + animasyonlu guncelle |

---

## Offline-First Mimari

```
┌─────────────────────┐
│   Flutter UI         │
│   Riverpod State     │
└──────────┬──────────┘
           │
    ┌──────▼──────┐     ┌──────────────┐
    │  Services    │────▶│  API (Dio)   │──▶ Backend
    │  (CRUD)      │     └──────────────┘
    └──────┬──────┘
           │ offline?
    ┌──────▼──────┐
    │  SQLite DB   │
    │  + Sync Queue│
    └─────────────┘
```

- **Online:** API uzerinden veri okuma/yazma, yerel cache guncelleme
- **Offline:** SQLite'tan okuma, degisiklikleri sync queue'ya ekleme
- **Senkronizasyon:** Online olunca queue'daki islemleri sirayla API'ye gonderme
- **Catisma:** Sunucu tarafli dogrulama, temp ID → gercek ID donusumu
- **Veri koruma:** Offline modda cikis engeli (senkronize edilmemis veri varsa)

---

## iOS vs Android

Flutter tek codebase ile her iki platform icin ayni uygulama uretilir.

| Ozellik | iOS | Android |
|---------|-----|---------|
| UI / Tasarim | Ayni | Ayni |
| Islevsellik | Ayni | Ayni |
| Barkod tarama | Ayni | Ayni |
| Offline mode | Ayni | Ayni |
| Excel/PDF export | Ayni | Ayni |
| **Token saklama** | Keychain | EncryptedSharedPreferences |
| **ATS (HTTP korumasi)** | Aktif (dev IP exception) | Yok |
| **Network security** | Info.plist | network_security_config yok |
| **Build** | `flutter build ios` | `flutter build apk` |

> Tasarim ve islevsellik %100 ayni. Fark yalnizca platform guvenlik konfigurasyonlarinda.

---

## Kurulum

### Gereksinimler
- Flutter SDK 3.11+
- Xcode (iOS icin)
- Android Studio / SDK (Android icin)
- Backend API calisiyor olmali (`localhost:3001`)

### Baslangic

```bash
cd mobile
flutter pub get

# API adresini ayarla
# lib/config/api_config.dart → _devUrl icindeki IP'yi degistir
```

### Calistirma

```bash
flutter run                   # Bagli cihaza yukle
flutter run -d chrome          # Web debug (deneysel)
```

### Build

```bash
flutter build apk --release   # Android APK
flutter build ios --release   # iOS (Xcode gerekli)
```

---

## Backend Baglantisi

Bu uygulama StokSay Backend API'sine baglanir:

| Ortam | URL |
|-------|-----|
| Development | `http://<BILGISAYAR_IP>:3001/api` |
| Production | `https://stoksay.com/api` |

Konfigürasyon: `lib/config/api_config.dart`

---

## Guvenlik

Detayli guvenlik raporu: [`SECURITY.md`](SECURITY.md)

### Ozet
- JWT token FlutterSecureStorage ile saklanir (Keychain / EncryptedSharedPreferences)
- Token suresi client-side kontrol edilir (exp + 30 sn tampon)
- Offline ID: `Random.secure()` ile kriptografik rastgelelik
- Sync queue: hata_sayisi >= 3 olan kayitlar temizlenir
- LIKE injection koruması: JSON decode ile tam esleme
- Pull data validation: bos ID kontrolu
- Pasif kullanici: dark ekran, sadece cikis yapilabilir
- App foreground'da yetki bilgileri yeniden kontrol edilir
- 500 hatalari genel mesajla gosterilir (sunucu detaylari gizlenir)

---

## Surum Gecmisi

| Surum | Tarih | Aciklama |
|-------|-------|----------|
| **v4.1.2** | 2026-03-17 | Guvenlik denetimi, penetrasyon testi, dokumantasyon guncellemesi |
| **v4.1.1** | 2026-03-17 | Pasif kullanici ekrani, yetkisiz ekran, XLSX export |
| **v4.0** | 2026-03-17 | Offline/online mod, senkronizasyon, aktif sayim korumasi |
| **v3.3** | 2026-03-16 | 12 guvenlik acigi kapatildi |
| **v3.1** | 2026-03-15 | flutter_secure_storage, sayim ID gosterim |
| **v2** | 2026-03-14 | Flutter mobil, offline-first, barkod tarayici |

---

## Repo

| Repo | URL |
|------|-----|
| Mobil Uygulama | [github.com/Hasanheybat/stoksay-mobile](https://github.com/Hasanheybat/stoksay-mobile) |
| Backend + Admin | [github.com/Hasanheybat/stoksayim](https://github.com/Hasanheybat/stoksayim) |

---

## Lisans

Bu proje ozel kullanim icindir.

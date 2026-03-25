# StokSay Mobile - Guvenlik

**Son Tarama:** 2026-03-17 (v4.1.2)

## Kimlik Dogrulama
- JWT token tabanli kimlik dogrulama
- Token `FlutterSecureStorage` ile guvenlice saklanir (Keychain/EncryptedSharedPreferences)
- Her API isteginde `Authorization: Bearer <token>` header'i eklenir
- Token suresi doldugunda otomatik logout (client-side JWT exp kontrolu, 30 sn tampon)
- Login'de email format ve sifre minimum 8 karakter dogrulamasi
- App foreground'a geldiginde yetki bilgileri yeniden kontrol edilir

## Veri Guvenligi

### Yerel Veri (SQLite)
- Tum offline veriler cihaz uzerindeki SQLite veritabaninda saklanir
- Veritabani Flutter'in uygulama dizininde tutulur (sandbox)
- Kullanici cikarisinda token ve tum yerel veriler temizlenir

### Sync Queue
- Senkronizasyon kuyrugu `sync_queue` tablosunda tutulur
- Her kayit tablo adi, islem tipi ve JSON veri icerir
- Basarili gonderilen kayitlar kuyruktan silinir
- Hata durumunda `hata_sayisi` artar, 3+ hatada kayit otomatik silinir
- Yerel DB guncellemeleri SQLite transaction icinde atomik yapilir
- LIKE injection koruması: JSON decode ile tam esleme kontrolu

### Pull Data Validation
- Sunucudan gelen veriler insert oncesi dogrulanir (bos ID kontrolu)
- Gecersiz kayitlar atlanir

### API Iletisimi
- HTTPS uzerinden sifrelenmis iletisim (production)
- iOS ATS: NSAllowsArbitraryLoads kapatildi, sadece dev IP'ye HTTP izni
- Dio interceptor ile token yonetimi
- 401 hatalarinda otomatik logout
- 500 hatalari kullaniciya genel mesajla gosterilir (sunucu detaylari gizlenir)
- Dev sunucu IP'si ortam degiskeni ile konfigure edilir (prod build'de gizlenir)

## Offline ID Guvenligi
- Tahmin edilemez offline ID: `temp_{timestamp}_{random}` formati
- Random.secure() ile kriptografik rastgelelik
- isTempId() kontrolu ile temp/gercek ID ayrimi

## Cache Fallback Bildirimi
- Sunucuya ulasilamazsa cache'ten veri gosterilir
- Kullaniciya "Cevrimdisi veri gosteriliyor" bildirimi verilir

## Pasif Kullanici Korumasi
- authGuard 403 dondugunde pasif state aktiflesir
- Cache fallback atlanir, yetkilerMap bos olarak ayarlanir
- Dark ekran: unlem ikonu + "Hesabiniz pasife alindi" uyarisi
- Sadece cikis yap butonu aktif, baska islem yapilamaz
- Offline modda cikis engeli: veri kaybi onlenir

## Yetkisiz Kullanici Ekrani
- Yetki atanmamis kullanici dark ekranla karsilanir
- Animasyonlu guncelle butonu ile yetki sonrasi normale donus
- Atanan yetkiler listesi goruntulenir

## Hassas Veri Yonetimi
- Kullanici parolasi cihazda saklanmaz
- JWT token FlutterSecureStorage ile korunur
- Offline veriler yalnizca kullanicinin isletme verilerini icerir

## Offline Mod Guvenligi
- Offline modda tum veriler yerel SQLite'ta islenenir
- Sync queue yalnizca kullanicinin kendi islemlerini icerir
- Senkronizasyonda sunucu tarafli dogrulama yapilir

## Platform Farklari

| Ozellik | iOS | Android |
|---------|-----|---------|
| Token saklama | Keychain | EncryptedSharedPreferences |
| ATS (HTTP korumasi) | Aktif (dev IP exception) | Yok |
| Network security config | Info.plist | Yok |

## Bilinen Sinirlamalar
- SQLite veritabani sifrelenmemistir (cihaz guvenligi ile korunur)
- Root/jailbreak cihazlarda veri erisimi mumkundur
- Offline moddayken sunucu tarafli yetkilendirme atlanir (sync sirasinda kontrol edilir)
- Certificate pinning henuz uygulanmamistir
- Ekran goruntusu korumasi henuz uygulanmamistir
- Android network_security_config.xml henuz eklenmemistir

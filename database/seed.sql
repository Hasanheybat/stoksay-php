-- StokSay Seed Data
-- Admin kullanici ve sistem rolleri

SET NAMES utf8mb4;

-- Admin kullanici
INSERT INTO kullanicilar (id, ad_soyad, email, password_hash, rol, aktif)
VALUES (
    UUID(),
    'Admin',
    'admin@stoksay.com',
    '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjfdQBjMO1FZpxMBNj2VYr/VNhCcGi',
    'admin',
    1
);

-- Sistem rolleri
INSERT INTO roller (id, ad, yetkiler, sistem) VALUES
(
    UUID(),
    'Tam Yetkili',
    JSON_OBJECT(
        'isletme', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', true),
        'depo', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', true),
        'urun', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', true),
        'sayim', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', true),
        'kullanici', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', true),
        'rapor', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', true)
    ),
    1
),
(
    UUID(),
    'Sayimci',
    JSON_OBJECT(
        'isletme', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'depo', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'urun', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'sayim', JSON_OBJECT('goruntule', true, 'duzenle', true, 'sil', false),
        'kullanici', JSON_OBJECT('goruntule', false, 'duzenle', false, 'sil', false),
        'rapor', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false)
    ),
    1
),
(
    UUID(),
    'Goruntuleici',
    JSON_OBJECT(
        'isletme', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'depo', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'urun', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'sayim', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false),
        'kullanici', JSON_OBJECT('goruntule', false, 'duzenle', false, 'sil', false),
        'rapor', JSON_OBJECT('goruntule', true, 'duzenle', false, 'sil', false)
    ),
    1
);

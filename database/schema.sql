-- StokSay Veritabani Semasi
-- MySQL 8.0+

SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- Tablolari FK sirasina gore sil (once bagimli olanlar)
DROP TABLE IF EXISTS rate_limits;
DROP TABLE IF EXISTS urun_log;
DROP TABLE IF EXISTS sayim_kalemleri;
DROP TABLE IF EXISTS sayimlar;
DROP TABLE IF EXISTS isletme_urunler;
DROP TABLE IF EXISTS kullanici_isletme;
DROP TABLE IF EXISTS roller;
DROP TABLE IF EXISTS kullanicilar;
DROP TABLE IF EXISTS depolar;
DROP TABLE IF EXISTS isletmeler;

-- 1. isletmeler
CREATE TABLE isletmeler (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    ad VARCHAR(200) NOT NULL,
    kod VARCHAR(50) NOT NULL UNIQUE,
    adres TEXT,
    telefon VARCHAR(20),
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. depolar
CREATE TABLE depolar (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    isletme_id CHAR(36) NOT NULL,
    ad VARCHAR(200) NOT NULL,
    kod VARCHAR(50) NOT NULL,
    konum TEXT,
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_depolar_isletme_kod (isletme_id, kod),
    CONSTRAINT fk_depolar_isletme FOREIGN KEY (isletme_id) REFERENCES isletmeler(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. kullanicilar
CREATE TABLE kullanicilar (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    ad_soyad VARCHAR(200) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(20) NOT NULL DEFAULT 'kullanici' CHECK (rol IN ('admin', 'kullanici')),
    telefon VARCHAR(20),
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    ayarlar JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. roller
CREATE TABLE roller (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    ad VARCHAR(100) NOT NULL UNIQUE,
    yetkiler JSON,
    sistem TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. kullanici_isletme
CREATE TABLE kullanici_isletme (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    kullanici_id CHAR(36) NOT NULL,
    isletme_id CHAR(36) NOT NULL,
    rol_id CHAR(36) DEFAULT NULL,
    yetkiler JSON NOT NULL,
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kullanici_isletme (kullanici_id, isletme_id),
    CONSTRAINT fk_ki_kullanici FOREIGN KEY (kullanici_id) REFERENCES kullanicilar(id),
    CONSTRAINT fk_ki_isletme FOREIGN KEY (isletme_id) REFERENCES isletmeler(id),
    CONSTRAINT fk_ki_rol FOREIGN KEY (rol_id) REFERENCES roller(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. isletme_urunler
CREATE TABLE isletme_urunler (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    isletme_id CHAR(36) NOT NULL,
    urun_kodu VARCHAR(100) NOT NULL,
    urun_adi VARCHAR(500) NOT NULL,
    isim_2 VARCHAR(500),
    birim VARCHAR(50) NOT NULL DEFAULT 'ADET',
    kategori VARCHAR(100),
    aciklama TEXT,
    barkodlar VARCHAR(5000),
    admin_version INT NOT NULL DEFAULT 1,
    kullanici_guncelledi TINYINT(1) NOT NULL DEFAULT 0,
    guncelleme_kaynagi VARCHAR(20) NOT NULL DEFAULT 'admin',
    son_guncelleme DATETIME,
    guncelleyen_kullanici_id CHAR(36),
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_isletme_urun_kodu (isletme_id, urun_kodu),
    CONSTRAINT fk_urunler_isletme FOREIGN KEY (isletme_id) REFERENCES isletmeler(id),
    CONSTRAINT fk_urunler_guncelleyen FOREIGN KEY (guncelleyen_kullanici_id) REFERENCES kullanicilar(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. sayimlar
CREATE TABLE sayimlar (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    isletme_id CHAR(36) NOT NULL,
    depo_id CHAR(36) NOT NULL,
    kullanici_id CHAR(36) NOT NULL,
    ad VARCHAR(300) NOT NULL,
    tarih DATE NOT NULL,
    durum VARCHAR(30) NOT NULL DEFAULT 'devam' CHECK (durum IN ('devam', 'tamamlandi', 'silindi')),
    kisiler TEXT,
    notlar TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_sayimlar_isletme FOREIGN KEY (isletme_id) REFERENCES isletmeler(id),
    CONSTRAINT fk_sayimlar_depo FOREIGN KEY (depo_id) REFERENCES depolar(id),
    CONSTRAINT fk_sayimlar_kullanici FOREIGN KEY (kullanici_id) REFERENCES kullanicilar(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. sayim_kalemleri
CREATE TABLE sayim_kalemleri (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    sayim_id CHAR(36) NOT NULL,
    urun_id CHAR(36) NOT NULL,
    miktar DECIMAL(12,3) NOT NULL,
    birim VARCHAR(50),
    notlar TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_kalemler_sayim FOREIGN KEY (sayim_id) REFERENCES sayimlar(id) ON DELETE CASCADE,
    CONSTRAINT fk_kalemler_urun FOREIGN KEY (urun_id) REFERENCES isletme_urunler(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. urun_log
CREATE TABLE urun_log (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    urun_id CHAR(36) NOT NULL,
    isletme_id CHAR(36) NOT NULL,
    kullanici_id CHAR(36),
    islem VARCHAR(30) NOT NULL,
    onceki_deger JSON,
    yeni_deger JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_log_urun FOREIGN KEY (urun_id) REFERENCES isletme_urunler(id),
    CONSTRAINT fk_log_kullanici FOREIGN KEY (kullanici_id) REFERENCES kullanicilar(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. rate_limits
CREATE TABLE rate_limits (
    id INT NOT NULL AUTO_INCREMENT,
    rate_key VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_rate_key_created (rate_key, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

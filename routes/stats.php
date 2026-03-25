<?php
/**
 * Stats Routes — /api/stats/*
 * Auth + admin gerektirir.
 */

function register_stats_routes(Router $router): void {
    $mw = [auth_guard(), admin_guard()];

    // GET /api/stats — Dashboard toplu istatistikler
    $router->get('/stats', function ($req) {
        $pdo = get_db();

        $isletme = (int)$pdo->query('SELECT COUNT(*) FROM isletmeler WHERE aktif = 1')->fetchColumn();
        $depo    = (int)$pdo->query('SELECT COUNT(*) FROM depolar WHERE aktif = 1')->fetchColumn();
        $kullanici = (int)$pdo->query('SELECT COUNT(*) FROM kullanicilar WHERE aktif = 1')->fetchColumn();
        $urun    = (int)$pdo->query('SELECT COUNT(*) FROM isletme_urunler WHERE aktif = 1')->fetchColumn();

        $stmt = $pdo->prepare("SELECT COUNT(*) FROM sayimlar WHERE durum = ?");
        $stmt->execute(['devam']);
        $sayim_devam = (int)$stmt->fetchColumn();

        $stmt->execute(['tamamlandi']);
        $sayim_tamamlandi = (int)$stmt->fetchColumn();

        json_response([
            'isletme'           => $isletme,
            'depo'              => $depo,
            'kullanici'         => $kullanici,
            'urun'              => $urun,
            'sayim_devam'       => $sayim_devam,
            'sayim_tamamlandi'  => $sayim_tamamlandi,
            'sayim_toplam'      => $sayim_devam + $sayim_tamamlandi,
        ]);
    }, $mw);

    // GET /api/stats/sayim-trend — Son 6 aylık sayım trendi
    $router->get('/stats/sayim-trend', function ($req) {
        $pdo = get_db();

        $stmt = $pdo->prepare(
            "SELECT durum, created_at
             FROM sayimlar
             WHERE durum <> 'silindi'
               AND created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
             ORDER BY created_at ASC"
        );
        $stmt->execute();
        $rows = $stmt->fetchAll();

        json_response($rows);
    }, $mw);

    // GET /api/stats/isletme-sayimlar — İşletme bazlı sayım dağılımı (top 10)
    $router->get('/stats/isletme-sayimlar', function ($req) {
        $pdo = get_db();

        $stmt = $pdo->prepare(
            "SELECT i.ad,
                    COUNT(s.id) AS toplam,
                    SUM(CASE WHEN s.durum = 'devam' THEN 1 ELSE 0 END) AS devam,
                    SUM(CASE WHEN s.durum = 'tamamlandi' THEN 1 ELSE 0 END) AS tamamlandi
             FROM sayimlar s
             JOIN isletmeler i ON i.id = s.isletme_id
             WHERE s.durum <> 'silindi'
             GROUP BY s.isletme_id, i.ad
             ORDER BY toplam DESC
             LIMIT 10"
        );
        $stmt->execute();
        $rows = $stmt->fetchAll();

        foreach ($rows as &$row) {
            $row['toplam']      = (int)$row['toplam'];
            $row['devam']       = (int)$row['devam'];
            $row['tamamlandi']  = (int)$row['tamamlandi'];
        }
        unset($row);

        json_response($rows);
    }, $mw);

    // GET /api/stats/son-sayimlar — Son 5 sayım (detaylı)
    $router->get('/stats/son-sayimlar', function ($req) {
        $pdo = get_db();

        $stmt = $pdo->prepare(
            "SELECT s.*,
                    i.id AS isletme_id, i.ad AS isletme_adi, i.kod AS isletme_kod,
                    d.id AS depo_id, d.ad AS depo_adi, d.kod AS depo_kod,
                    k.id AS kullanici_id, k.ad_soyad AS kullanici_ad_soyad, k.email AS kullanici_email
             FROM sayimlar s
             LEFT JOIN isletmeler i ON i.id = s.isletme_id
             LEFT JOIN depolar d ON d.id = s.depo_id
             LEFT JOIN kullanicilar k ON k.id = s.kullanici_id
             WHERE s.durum <> 'silindi'
             ORDER BY s.created_at DESC
             LIMIT 5"
        );
        $stmt->execute();
        $rows = $stmt->fetchAll();

        $result = [];
        foreach ($rows as $row) {
            $sayim = [
                'id'         => $row['id'],
                'durum'      => $row['durum'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at'],
            ];

            $sayim['isletme'] = [
                'id'  => $row['isletme_id'],
                'ad'  => $row['isletme_adi'],
                'kod' => $row['isletme_kod'],
            ];

            $sayim['depo'] = [
                'id'  => $row['depo_id'],
                'ad'  => $row['depo_adi'],
                'kod' => $row['depo_kod'],
            ];

            $sayim['kullanici'] = [
                'id'       => $row['kullanici_id'],
                'ad_soyad' => $row['kullanici_ad_soyad'],
                'email'    => $row['kullanici_email'],
            ];

            $result[] = $sayim;
        }

        json_response($result);
    }, $mw);
}

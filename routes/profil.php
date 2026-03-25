<?php
/**
 * Profil Routes — /api/profil/*
 * Auth gerektirir, admin gerektirmez.
 */

function register_profil_routes(Router $router): void {
    $mw = [auth_guard()];

    // GET /api/profil/isletmelerim — Kullanıcının işletmeleri
    $router->get('/profil/isletmelerim', function ($req) {
        $pdo    = get_db();
        $userId = $req['user']['id'];

        $stmt = $pdo->prepare(
            'SELECT i.id, i.ad, i.kod, i.aktif
             FROM kullanici_isletme ki
             JOIN isletmeler i ON i.id = ki.isletme_id
             WHERE ki.kullanici_id = ? AND ki.aktif = 1'
        );
        $stmt->execute([$userId]);
        $rows = $stmt->fetchAll();

        foreach ($rows as &$row) {
            $row['aktif'] = (bool)(int)$row['aktif'];
        }
        unset($row);

        json_response($rows);
    }, $mw);

    // GET /api/profil/stats — Kullanıcı istatistikleri
    $router->get('/profil/stats', function ($req) {
        $pdo    = get_db();
        $userId = $req['user']['id'];

        // Kullanıcının işletme ID'lerini al
        $stmt = $pdo->prepare(
            'SELECT isletme_id FROM kullanici_isletme WHERE kullanici_id = ? AND aktif = 1'
        );
        $stmt->execute([$userId]);
        $isletmeIds = $stmt->fetchAll(PDO::FETCH_COLUMN);

        // Sayımlar — kullanıcının kendi oluşturduğu ve silinmemiş
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM sayimlar WHERE kullanici_id = ? AND durum <> 'silindi'"
        );
        $stmt->execute([$userId]);
        $sayimlar = (int)$stmt->fetchColumn();

        $urunler = 0;
        $depolar = 0;

        if (!empty($isletmeIds)) {
            $placeholders = implode(',', array_fill(0, count($isletmeIds), '?'));

            // Ürünler — kullanıcının işletmelerindeki aktif ürünler
            $stmt = $pdo->prepare(
                "SELECT COUNT(*) FROM isletme_urunler WHERE isletme_id IN ($placeholders) AND aktif = 1"
            );
            $stmt->execute($isletmeIds);
            $urunler = (int)$stmt->fetchColumn();

            // Depolar — kullanıcının işletmelerindeki aktif depolar
            $stmt = $pdo->prepare(
                "SELECT COUNT(*) FROM depolar WHERE isletme_id IN ($placeholders) AND aktif = 1"
            );
            $stmt->execute($isletmeIds);
            $depolar = (int)$stmt->fetchColumn();
        }

        json_response([
            'sayimlar' => $sayimlar,
            'urunler'  => $urunler,
            'depolar'  => $depolar,
        ]);
    }, $mw);

    // PUT /api/profil/ayarlar — Kullanıcı ayarlarını güncelle
    $router->put('/profil/ayarlar', function ($req) {
        $pdo     = get_db();
        $userId  = $req['user']['id'];
        $ayarlar = $req['body']['ayarlar'] ?? null;

        if ($ayarlar === null) json_error(__t('general.ayarlar_required'), 400);

        $ayarlarJson = json_encode($ayarlar, JSON_UNESCAPED_UNICODE);

        $stmt = $pdo->prepare('UPDATE kullanicilar SET ayarlar = ?, updated_at = NOW() WHERE id = ?');
        $stmt->execute([$ayarlarJson, $userId]);

        json_response(['ok' => true]);
    }, $mw);
}

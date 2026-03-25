<?php
/**
 * Kullanıcılar Routes — /api/kullanicilar/*
 * Tüm route'lar auth + admin gerektirir.
 */

function register_kullanicilar_routes(Router $router): void {
    $mw = [auth_guard(), admin_guard()];

    // GET /api/kullanicilar — Kullanıcı listesi (pagination, arama, filtre)
    $router->get('/kullanicilar', function ($req) {
        $pdo   = get_db();
        $query = $req['query'];
        $q     = trim($query['q'] ?? '');
        $durum = $query['durum'] ?? '';   // Aktif / Pasif
        $rol   = $query['rol'] ?? '';
        $sayfa = $query['sayfa'] ?? null;

        // Base WHERE
        $where  = ['k.aktif = 1'];
        $params = [];

        if ($q !== '') {
            $where[]  = '(k.ad_soyad LIKE ? OR k.email LIKE ?)';
            $params[] = "%$q%";
            $params[] = "%$q%";
        }
        if ($durum === 'Aktif') {
            $where[] = 'k.aktif = 1';
        } elseif ($durum === 'Pasif') {
            $where[] = 'k.aktif = 0';
        }
        if ($rol !== '') {
            $where[]  = 'k.rol = ?';
            $params[] = $rol;
        }

        $whereSql = implode(' AND ', $where);

        // Paginated mi?
        if ($sayfa !== null) {
            [$sayfaNo, $limit, $offset] = parse_pagination($query);

            // Toplam
            $countSql = "SELECT COUNT(DISTINCT k.id) FROM kullanicilar k WHERE $whereSql";
            $stmt     = $pdo->prepare($countSql);
            $stmt->execute($params);
            $toplam = (int) $stmt->fetchColumn();

            // Kullanıcılar
            $sql = "SELECT k.id, k.ad_soyad, k.email, k.rol, k.telefon, k.aktif,
                           k.created_at
                    FROM kullanicilar k
                    WHERE $whereSql
                    ORDER BY k.created_at DESC
                    LIMIT $limit OFFSET $offset";
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $rows = $stmt->fetchAll();
        } else {
            $sql = "SELECT k.id, k.ad_soyad, k.email, k.rol, k.telefon, k.aktif,
                           k.created_at
                    FROM kullanicilar k
                    WHERE $whereSql
                    ORDER BY k.created_at DESC";
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $rows = $stmt->fetchAll();
        }

        // Her kullanıcı için işletme listesini çek
        if (!empty($rows)) {
            $ids          = array_column($rows, 'id');
            $placeholders = implode(',', array_fill(0, count($ids), '?'));

            $islSql = "SELECT ki.kullanici_id, ki.isletme_id, ki.aktif AS ki_aktif,
                              i.ad AS isletme_adi, i.kod AS isletme_kod
                       FROM kullanici_isletme ki
                       LEFT JOIN isletmeler i ON i.id = ki.isletme_id
                       WHERE ki.kullanici_id IN ($placeholders) AND ki.aktif = 1";
            $stmt = $pdo->prepare($islSql);
            $stmt->execute($ids);
            $islRows = $stmt->fetchAll();

            $map = [];
            foreach ($islRows as $ir) {
                $map[$ir['kullanici_id']][] = [
                    'isletme_id'  => $ir['isletme_id'],
                    'ad'          => $ir['isletme_adi'],
                    'kod'         => $ir['isletme_kod'],
                    'aktif'       => (bool)(int)$ir['ki_aktif'],
                ];
            }

            foreach ($rows as &$row) {
                $row['aktif']      = (bool)(int)$row['aktif'];
                $row['isletmeler'] = $map[$row['id']] ?? [];
            }
            unset($row);
        }

        if ($sayfa !== null) {
            json_response(['data' => $rows, 'toplam' => $toplam]);
        } else {
            json_response($rows);
        }
    }, $mw);

    // GET /api/kullanicilar/:id — Detay
    $router->get('/kullanicilar/:id', function ($req) {
        $pdo = get_db();
        $id  = $req['params']['id'];

        $stmt = $pdo->prepare('SELECT * FROM kullanicilar WHERE id = ? AND aktif = 1');
        $stmt->execute([$id]);
        $user = $stmt->fetch();
        if (!$user) json_error('Kullanıcı bulunamadı.', 404);

        $user = remove_password_hash($user);
        $user['aktif'] = (bool)(int)$user['aktif'];
        if (isset($user['ayarlar']) && is_string($user['ayarlar'])) {
            $user['ayarlar'] = json_decode($user['ayarlar'], true);
        }

        // İşletme atamaları
        $stmt = $pdo->prepare(
            'SELECT ki.isletme_id, ki.yetkiler, ki.rol_id, ki.aktif AS ki_aktif,
                    i.ad AS isletme_adi, i.kod AS isletme_kod,
                    r.ad AS rol_adi
             FROM kullanici_isletme ki
             LEFT JOIN isletmeler i ON i.id = ki.isletme_id
             LEFT JOIN roller r ON r.id = ki.rol_id
             WHERE ki.kullanici_id = ?'
        );
        $stmt->execute([$id]);
        $isletmeler = $stmt->fetchAll();

        foreach ($isletmeler as &$isl) {
            $isl['aktif']    = (bool)(int)$isl['ki_aktif'];
            $isl['yetkiler'] = json_decode($isl['yetkiler'], true);
            unset($isl['ki_aktif']);
        }
        unset($isl);

        $user['kullanici_isletme'] = $isletmeler;
        json_response($user);
    }, $mw);

    // POST /api/kullanicilar — Yeni kullanıcı
    $router->post('/kullanicilar', function ($req) {
        $body = $req['body'];

        $ad_soyad = trim($body['ad_soyad'] ?? '');
        $email    = trim($body['email'] ?? '');
        $sifre    = $body['sifre'] ?? '';
        $rol      = $body['rol'] ?? 'kullanici';
        $telefon  = trim($body['telefon'] ?? '');

        // Validasyonlar
        if ($ad_soyad === '') json_error('Ad soyad zorunludur.', 400);
        if (mb_strlen($ad_soyad) > 100) json_error('Ad soyad en fazla 100 karakter olabilir.', 400);
        if ($email === '') json_error('Email zorunludur.', 400);
        if (mb_strlen($email) > 255) json_error('Email en fazla 255 karakter olabilir.', 400);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) json_error('Geçerli bir email adresi giriniz.', 400);
        if ($sifre === '') json_error('Şifre zorunludur.', 400);
        if (mb_strlen($sifre) < 8) json_error('Şifre en az 8 karakter olmalıdır.', 400);
        if (mb_strlen($sifre) > 128) json_error('Şifre en fazla 128 karakter olabilir.', 400);
        if (!in_array($rol, ['admin', 'kullanici'], true)) json_error('Geçersiz rol.', 400);
        if ($telefon !== '' && !preg_match('/^\+?[0-9\s\-()]{7,20}$/', $telefon)) {
            json_error('Geçerli bir telefon numarası giriniz.', 400);
        }

        $pdo  = get_db();
        $id   = uuid_v4();
        $hash = password_hash($sifre, PASSWORD_BCRYPT, ['cost' => 10]);

        try {
            $stmt = $pdo->prepare(
                'INSERT INTO kullanicilar (id, ad_soyad, email, password_hash, rol, telefon, aktif, created_at)
                 VALUES (?, ?, ?, ?, ?, ?, 1, NOW())'
            );
            $stmt->execute([$id, $ad_soyad, $email, $hash, $rol, $telefon ?: null]);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu email zaten kullanılıyor.', 409);
            }
            throw $e;
        }

        $stmt = $pdo->prepare('SELECT * FROM kullanicilar WHERE id = ?');
        $stmt->execute([$id]);
        $user = remove_password_hash($stmt->fetch());
        $user['aktif'] = (bool)(int)$user['aktif'];

        json_response($user, 201);
    }, $mw);

    // PUT /api/kullanicilar/:id — Güncelle
    $router->put('/kullanicilar/:id', function ($req) {
        $pdo  = get_db();
        $id   = $req['params']['id'];
        $body = $req['body'];
        $me   = $req['user']['id'];

        // Kullanıcı var mı?
        $stmt = $pdo->prepare('SELECT * FROM kullanicilar WHERE id = ? AND aktif = 1');
        $stmt->execute([$id]);
        $user = $stmt->fetch();
        if (!$user) json_error('Kullanıcı bulunamadı.', 404);

        // Kendini koruma
        if ($id === $me) {
            if (isset($body['rol']) && $body['rol'] !== 'admin') {
                json_error('Kendi admin rolünüzü değiştiremezsiniz.', 403);
            }
            if (isset($body['aktif']) && !(bool)(int)$body['aktif']) {
                json_error('Kendinizi pasif yapamazsınız.', 403);
            }
        }

        $fields = [];
        $params = [];

        $allowed = ['ad_soyad', 'email', 'rol', 'telefon'];
        foreach ($allowed as $field) {
            if (array_key_exists($field, $body)) {
                $fields[] = "$field = ?";
                $params[] = $body[$field];
            }
        }
        if (array_key_exists('aktif', $body)) {
            $fields[] = 'aktif = ?';
            $params[] = $body['aktif'] ? 1 : 0;
        }

        // Şifre güncelleme
        if (!empty($body['sifre'])) {
            $sifre = $body['sifre'];
            if (mb_strlen($sifre) < 8) json_error('Şifre en az 8 karakter olmalıdır.', 400);
            if (mb_strlen($sifre) > 128) json_error('Şifre en fazla 128 karakter olabilir.', 400);
            $fields[] = 'password_hash = ?';
            $params[] = password_hash($sifre, PASSWORD_BCRYPT, ['cost' => 10]);
        }

        if (empty($fields)) json_error('Güncellenecek alan bulunamadı.', 400);

        // Validasyonlar
        if (isset($body['ad_soyad']) && mb_strlen($body['ad_soyad']) > 100) {
            json_error('Ad soyad en fazla 100 karakter olabilir.', 400);
        }
        if (isset($body['email'])) {
            if (!filter_var($body['email'], FILTER_VALIDATE_EMAIL)) {
                json_error('Geçerli bir email adresi giriniz.', 400);
            }
            if (mb_strlen($body['email']) > 255) {
                json_error('Email en fazla 255 karakter olabilir.', 400);
            }
        }
        if (isset($body['rol']) && !in_array($body['rol'], ['admin', 'kullanici'], true)) {
            json_error('Geçersiz rol.', 400);
        }
        if (isset($body['telefon']) && $body['telefon'] !== '' && !preg_match('/^\+?[0-9\s\-()]{7,20}$/', $body['telefon'])) {
            json_error('Geçerli bir telefon numarası giriniz.', 400);
        }

        $params[] = $id;

        $sql = 'UPDATE kullanicilar SET ' . implode(', ', $fields) . ' WHERE id = ?';
        try {
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu email zaten kullanılıyor.', 409);
            }
            throw $e;
        }

        $stmt = $pdo->prepare('SELECT * FROM kullanicilar WHERE id = ?');
        $stmt->execute([$id]);
        $updated = remove_password_hash($stmt->fetch());
        $updated['aktif'] = (bool)(int)$updated['aktif'];

        json_response($updated);
    }, $mw);

    // DELETE /api/kullanicilar/:id — Soft delete
    $router->delete('/kullanicilar/:id', function ($req) {
        $pdo = get_db();
        $id  = $req['params']['id'];
        $me  = $req['user']['id'];

        if ($id === $me) json_error('Kendinizi silemezsiniz.', 403);

        $stmt = $pdo->prepare('SELECT id FROM kullanicilar WHERE id = ? AND aktif = 1');
        $stmt->execute([$id]);
        if (!$stmt->fetch()) json_error('Kullanıcı bulunamadı.', 404);

        $stmt = $pdo->prepare('UPDATE kullanicilar SET aktif = 0 WHERE id = ?');
        $stmt->execute([$id]);

        json_response(['mesaj' => 'Kullanıcı pasife alındı.']);
    }, $mw);

    // POST /api/kullanicilar/:id/isletme — İşletme atama
    $router->post('/kullanicilar/:id/isletme', function ($req) {
        $pdo        = get_db();
        $id         = $req['params']['id'];
        $body       = $req['body'];
        $isletme_id = $body['isletme_id'] ?? null;

        if (!$isletme_id) json_error('isletme_id zorunludur.', 400);

        // Kullanıcı var mı?
        $stmt = $pdo->prepare('SELECT id FROM kullanicilar WHERE id = ? AND aktif = 1');
        $stmt->execute([$id]);
        if (!$stmt->fetch()) json_error('Kullanıcı bulunamadı.', 404);

        // İşletme var mı?
        $stmt = $pdo->prepare('SELECT id FROM isletmeler WHERE id = ? AND aktif = 1');
        $stmt->execute([$isletme_id]);
        if (!$stmt->fetch()) json_error('İşletme bulunamadı.', 404);

        $defaultYetkiler = json_encode([
            'urun' => ['goruntule' => true, 'ekle' => false, 'duzenle' => false, 'sil' => false],
            'depo' => ['goruntule' => true, 'ekle' => false, 'duzenle' => false, 'sil' => false],
            'sayim' => ['goruntule' => true, 'ekle' => false, 'duzenle' => false, 'sil' => false],
            'toplam_sayim' => ['goruntule' => false, 'ekle' => false, 'duzenle' => false, 'sil' => false],
        ], JSON_UNESCAPED_UNICODE);

        $kiId = uuid_v4();
        $stmt = $pdo->prepare(
            'INSERT INTO kullanici_isletme (id, kullanici_id, isletme_id, yetkiler, aktif)
             VALUES (?, ?, ?, ?, 1)
             ON DUPLICATE KEY UPDATE aktif = 1'
        );
        $stmt->execute([$kiId, $id, $isletme_id, $defaultYetkiler]);

        // Fetch the actual row
        $stmt = $pdo->prepare('SELECT * FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ?');
        $stmt->execute([$id, $isletme_id]);
        $row = $stmt->fetch();
        if ($row && isset($row['yetkiler']) && is_string($row['yetkiler'])) {
            $row['yetkiler'] = json_decode($row['yetkiler'], true);
        }
        if ($row) $row['aktif'] = (bool)(int)$row['aktif'];
        json_response($row, 201);
    }, $mw);

    // DELETE /api/kullanicilar/:id/isletme/:isletme_id — İşletme ataması kaldır
    $router->delete('/kullanicilar/:id/isletme/:isletme_id', function ($req) {
        $pdo        = get_db();
        $id         = $req['params']['id'];
        $isletme_id = $req['params']['isletme_id'];

        $stmt = $pdo->prepare(
            'UPDATE kullanici_isletme SET aktif = 0
             WHERE kullanici_id = ? AND isletme_id = ?'
        );
        $stmt->execute([$id, $isletme_id]);

        json_response(['mesaj' => 'İşletme ataması kaldırıldı.']);
    }, $mw);

    // GET /api/kullanicilar/:id/yetkiler — Yetkileri getir
    $router->get('/kullanicilar/:id/yetkiler', function ($req) {
        $pdo        = get_db();
        $id         = $req['params']['id'];
        $isletme_id = $req['query']['isletme_id'] ?? null;

        if (!$isletme_id) json_error('isletme_id query parametresi zorunludur.', 400);

        $stmt = $pdo->prepare(
            'SELECT ki.yetkiler, ki.rol_id, r.ad AS rol_adi
             FROM kullanici_isletme ki
             LEFT JOIN roller r ON r.id = ki.rol_id
             WHERE ki.kullanici_id = ? AND ki.isletme_id = ? AND ki.aktif = 1'
        );
        $stmt->execute([$id, $isletme_id]);
        $row = $stmt->fetch();

        if (!$row) json_error('Bu kullanıcı-işletme ataması bulunamadı.', 404);

        $row['yetkiler'] = json_decode($row['yetkiler'], true);
        json_response($row);
    }, $mw);

    // PUT /api/kullanicilar/:id/yetkiler — Yetkileri güncelle
    $router->put('/kullanicilar/:id/yetkiler', function ($req) {
        $pdo        = get_db();
        $id         = $req['params']['id'];
        $body       = $req['body'];
        $isletme_id = $body['isletme_id'] ?? null;
        $yetkiler   = $body['yetkiler'] ?? null;
        $rol_id     = $body['rol_id'] ?? null;

        if (!$isletme_id) json_error('isletme_id zorunludur.', 400);
        if ($yetkiler === null) json_error('yetkiler zorunludur.', 400);

        $yetkilerJson = json_encode($yetkiler, JSON_UNESCAPED_UNICODE);

        // Mevcut kayıt var mı?
        $stmt = $pdo->prepare(
            'SELECT kullanici_id FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ?'
        );
        $stmt->execute([$id, $isletme_id]);
        $exists = $stmt->fetch();

        if ($exists) {
            $fields = ['yetkiler = ?', 'aktif = 1'];
            $params = [$yetkilerJson];
            if ($rol_id !== null) {
                $fields[] = 'rol_id = ?';
                $params[] = $rol_id ?: null;
            }
            $params[] = $id;
            $params[] = $isletme_id;
            $stmt = $pdo->prepare('UPDATE kullanici_isletme SET ' . implode(', ', $fields) . ' WHERE kullanici_id = ? AND isletme_id = ?');
            $stmt->execute($params);
        } else {
            $kiId = uuid_v4();
            $rolParam = $rol_id !== null ? $rol_id : null;
            if ($rolParam !== null) {
                $stmt = $pdo->prepare('INSERT INTO kullanici_isletme (id, kullanici_id, isletme_id, yetkiler, rol_id, aktif) VALUES (?, ?, ?, ?, ?, 1)');
                $stmt->execute([$kiId, $id, $isletme_id, $yetkilerJson, $rolParam]);
            } else {
                $stmt = $pdo->prepare('INSERT INTO kullanici_isletme (id, kullanici_id, isletme_id, yetkiler, aktif) VALUES (?, ?, ?, ?, 1)');
                $stmt->execute([$kiId, $id, $isletme_id, $yetkilerJson]);
            }
        }

        $stmt = $pdo->prepare('SELECT * FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ?');
        $stmt->execute([$id, $isletme_id]);
        $row = $stmt->fetch();
        if ($row && isset($row['yetkiler']) && is_string($row['yetkiler'])) {
            $row['yetkiler'] = json_decode($row['yetkiler'], true);
        }
        if ($row) $row['aktif'] = (bool)(int)$row['aktif'];
        json_response($row);
    }, $mw);

    // PUT /api/kullanicilar/:id/restore — Silinen kullanıcıyı geri getir
    $router->put('/kullanicilar/:id/restore', function ($req) {
        $pdo = get_db();
        $id  = $req['params']['id'];

        $stmt = $pdo->prepare('SELECT id FROM kullanicilar WHERE id = ? AND aktif = 0');
        $stmt->execute([$id]);
        if (!$stmt->fetch()) json_error('Silinmiş kullanıcı bulunamadı.', 404);

        $stmt = $pdo->prepare('UPDATE kullanicilar SET aktif = 1 WHERE id = ?');
        $stmt->execute([$id]);

        json_response(['mesaj' => 'Kullanıcı geri alındı.']);
    }, $mw);
}

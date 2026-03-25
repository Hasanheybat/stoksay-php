<?php
/**
 * İşletmeler Routes — /api/isletmeler/*
 * Tüm route'lar auth + admin gerektirir
 */

function register_isletmeler_routes(Router $router): void {

    // GET /api/isletmeler?aktif=true&q=arama&sayfa=1&limit=50
    $router->get('/isletmeler', function ($req) {
        $query = $req['query'];
        $aktif = $query['aktif'] ?? null;
        $q     = $query['q'] ?? null;
        $sayfa = $query['sayfa'] ?? null;
        $limit = $query['limit'] ?? 50;

        try {
            $pdo = get_db();
            $conditions = [];
            $params = [];

            if ($aktif !== null) {
                $conditions[] = 'aktif = ?';
                $params[] = $aktif === 'true' ? 1 : 0;
            }

            if ($q) {
                $conditions[] = '(ad LIKE ? OR kod LIKE ?)';
                $params[] = "%{$q}%";
                $params[] = "%{$q}%";
            }

            $where = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';

            if ($sayfa) {
                [$sp, $lm, $offset] = parse_pagination($query);

                $countStmt = $pdo->prepare("SELECT COUNT(*) as toplam FROM isletmeler {$where}");
                $countStmt->execute($params);
                $toplam = (int)$countStmt->fetchColumn();

                $dataStmt = $pdo->prepare(
                    "SELECT * FROM isletmeler {$where} ORDER BY ad LIMIT {$lm} OFFSET {$offset}"
                );
                $dataStmt->execute($params);
                $data = $dataStmt->fetchAll();

                json_response(['data' => $data, 'toplam' => $toplam]);
            }

            // backward compat — dropdown listeler için
            $stmt = $pdo->prepare("SELECT * FROM isletmeler {$where} ORDER BY ad");
            $stmt->execute($params);
            $data = $stmt->fetchAll();

            json_response($data);
        } catch (PDOException $e) {
            error_log('[isletmeler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // GET /api/isletmeler/:id
    $router->get('/isletmeler/:id', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT * FROM isletmeler WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('İşletme bulunamadı.', 404);
            }

            json_response($row);
        } catch (PDOException $e) {
            error_log('[isletmeler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // POST /api/isletmeler
    $router->post('/isletmeler', function ($req) {
        $body = $req['body'];
        $ad      = $body['ad'] ?? null;
        $kod     = $body['kod'] ?? null;
        $adres   = $body['adres'] ?? null;
        $telefon = $body['telefon'] ?? null;

        if (!$ad || !$kod) {
            json_error('Ad ve kod zorunludur.', 400);
        }
        if (mb_strlen($ad) > 255) json_error('Ad en fazla 255 karakter olabilir.', 400);
        if (mb_strlen($kod) > 50)  json_error('Kod en fazla 50 karakter olabilir.', 400);
        if ($adres && mb_strlen($adres) > 500) json_error('Adres en fazla 500 karakter olabilir.', 400);
        if ($telefon && !preg_match('/^[0-9+\-\s()]{7,20}$/', $telefon)) {
            json_error('Geçerli bir telefon numarası giriniz.', 400);
        }

        try {
            $pdo = get_db();
            $id = uuid_v4();

            $stmt = $pdo->prepare(
                'INSERT INTO isletmeler (id, ad, kod, adres, telefon) VALUES (?, ?, ?, ?, ?)'
            );
            $stmt->execute([$id, $ad, $kod, $adres ?: null, $telefon ?: null]);

            $stmt = $pdo->prepare('SELECT * FROM isletmeler WHERE id = ?');
            $stmt->execute([$id]);
            $row = $stmt->fetch();

            json_response($row, 201);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu kod zaten kullanımda.', 409);
            }
            error_log('[isletmeler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // PUT /api/isletmeler/:id
    $router->put('/isletmeler/:id', function ($req) {
        $body = $req['body'];

        $telefon = $body['telefon'] ?? null;
        if ($telefon && !preg_match('/^[0-9+\-\s()]{7,20}$/', $telefon)) {
            json_error('Geçerli bir telefon numarası giriniz.', 400);
        }

        try {
            $pdo = get_db();
            $fields = [];
            $params = [];

            if (array_key_exists('ad', $body))      { $fields[] = 'ad = ?';      $params[] = $body['ad']; }
            if (array_key_exists('kod', $body))     { $fields[] = 'kod = ?';     $params[] = $body['kod']; }
            if (array_key_exists('adres', $body))   { $fields[] = 'adres = ?';   $params[] = $body['adres']; }
            if (array_key_exists('telefon', $body)) { $fields[] = 'telefon = ?'; $params[] = $body['telefon']; }
            if (array_key_exists('aktif', $body))   { $fields[] = 'aktif = ?';   $params[] = $body['aktif'] ? 1 : 0; }

            if (!$fields) {
                json_error('Güncellenecek alan yok.', 400);
            }

            $params[] = $req['params']['id'];

            $stmt = $pdo->prepare(
                'UPDATE isletmeler SET ' . implode(', ', $fields) . ' WHERE id = ?'
            );
            $stmt->execute($params);

            $stmt = $pdo->prepare('SELECT * FROM isletmeler WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('İşletme bulunamadı.', 404);
            }

            json_response($row);
        } catch (PDOException $e) {
            error_log('[isletmeler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // DELETE /api/isletmeler/:id — Soft delete (pasife al)
    $router->delete('/isletmeler/:id', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('UPDATE isletmeler SET aktif = 0 WHERE id = ?');
            $stmt->execute([$req['params']['id']]);

            json_response(['mesaj' => 'İşletme pasife alındı.']);
        } catch (PDOException $e) {
            error_log('[isletmeler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // PUT /api/isletmeler/:id/restore — Silinen işletmeyi geri al
    $router->put('/isletmeler/:id/restore', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT id, aktif FROM isletmeler WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('İşletme bulunamadı.', 404);
            }
            if ((int)$row['aktif'] === 1) {
                json_error('Bu işletme zaten aktif.', 400);
            }

            $stmt = $pdo->prepare('UPDATE isletmeler SET aktif = 1 WHERE id = ?');
            $stmt->execute([$req['params']['id']]);

            json_response(['mesaj' => 'İşletme geri alındı.']);
        } catch (PDOException $e) {
            error_log('[isletmeler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);
}

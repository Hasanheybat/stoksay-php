<?php
/**
 * Depolar Routes — /api/depolar/*
 * Kullanıcı + Admin rotaları tek handler içinde ayrılır
 */

/**
 * Yetki kontrol yardımcısı (PUT/DELETE için isletme_id DB'den çekilir)
 */
function check_depo_yetki(array $req, string $islem): bool {
    if ($req['user']['rol'] === 'admin') return true;

    $pdo = get_db();
    $stmt = $pdo->prepare('SELECT isletme_id FROM depolar WHERE id = ?');
    $stmt->execute([$req['params']['id']]);
    $depo = $stmt->fetch();

    if (!$depo) {
        json_error('Depo bulunamadı.', 404);
    }

    $stmt = $pdo->prepare(
        'SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1'
    );
    $stmt->execute([$req['user']['id'], $depo['isletme_id']]);
    $kiRow = $stmt->fetch();

    if (!$kiRow) {
        json_error('Bu işletmeye erişim yetkiniz yok.', 403);
    }

    $yetkiler = json_decode($kiRow['yetkiler'], true);
    if (!($yetkiler['depo'][$islem] ?? false)) {
        json_error("Depo {$islem} yetkiniz yok.", 403);
    }

    return true;
}

function register_depolar_routes(Router $router): void {

    // POST /api/depolar — Depo Ekle (kullanıcı: yetki_guard, admin: yetki_guard geçer)
    // Admin ek alanları (kod, konum) gönderebilir
    $router->post('/depolar', function ($req) {
        $body = $req['body'];
        $isletme_id = $body['isletme_id'] ?? null;
        $ad         = $body['ad'] ?? null;
        $kod        = $body['kod'] ?? null;
        $konum      = $body['konum'] ?? null;

        if (!$isletme_id || !$ad || !trim($ad)) {
            json_error('isletme_id ve ad zorunludur.', 400);
        }

        try {
            $pdo = get_db();
            $id = uuid_v4();

            // Admin ek alanlarla oluşturabilir
            if ($req['user']['rol'] === 'admin' && ($kod !== null || $konum !== null)) {
                $stmt = $pdo->prepare(
                    'INSERT INTO depolar (id, isletme_id, ad, kod, konum) VALUES (?, ?, ?, ?, ?)'
                );
                $stmt->execute([$id, $isletme_id, trim($ad), $kod ?: null, $konum ?: null]);
            } else {
                $stmt = $pdo->prepare('INSERT INTO depolar (id, isletme_id, ad) VALUES (?, ?, ?)');
                $stmt->execute([$id, $isletme_id, trim($ad)]);
            }

            $stmt = $pdo->prepare('SELECT * FROM depolar WHERE id = ?');
            $stmt->execute([$id]);
            $row = $stmt->fetch();

            json_response($row, 201);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu depo bu işletmede zaten var.', 409);
            }
            error_log('[depolar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), yetki_guard('depo', 'ekle', 'body')]);

    // PUT /api/depolar/:id — Kullanıcı: sadece ad | Admin: ad + kod + konum + aktif
    $router->put('/depolar/:id', function ($req) {
        check_depo_yetki($req, 'duzenle');

        $body = $req['body'];
        $ad = $body['ad'] ?? null;

        if (!$ad || !trim($ad)) {
            json_error('Depo adı boş olamaz.', 400);
        }

        // Admin ek alanları da güncelleyebilir; kullanıcı sadece ad
        $fields = ['ad = ?'];
        $params = [trim($ad)];

        if ($req['user']['rol'] === 'admin') {
            if (array_key_exists('kod', $body))   { $fields[] = 'kod = ?';   $params[] = $body['kod']; }
            if (array_key_exists('konum', $body)) { $fields[] = 'konum = ?'; $params[] = $body['konum']; }
            if (array_key_exists('aktif', $body)) { $fields[] = 'aktif = ?'; $params[] = $body['aktif'] ? 1 : 0; }
        }

        $params[] = $req['params']['id'];

        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('UPDATE depolar SET ' . implode(', ', $fields) . ' WHERE id = ?');
            $stmt->execute($params);

            $stmt = $pdo->prepare('SELECT * FROM depolar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('Depo bulunamadı.', 404);
            }

            json_response($row);
        } catch (PDOException $e) {
            error_log('[depolar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // DELETE /api/depolar/:id — Soft delete (aktif sayım kontrolü ile)
    $router->delete('/depolar/:id', function ($req) {
        check_depo_yetki($req, 'sil');

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            // Aktif sayımda kullanılıyor mu kontrol et (FOR UPDATE ile kilitle)
            $stmt = $pdo->prepare(
                "SELECT ad FROM sayimlar WHERE depo_id = ? AND durum = 'devam' FOR UPDATE"
            );
            $stmt->execute([$req['params']['id']]);
            $aktifSayimlar = $stmt->fetchAll();

            if (count($aktifSayimlar) > 0) {
                $pdo->rollBack();
                json_response([
                    'hata'     => 'Bu depo aktif sayımlarda kullanılıyor.',
                    'sayimlar' => array_column($aktifSayimlar, 'ad'),
                ], 409);
            }

            $stmt = $pdo->prepare('UPDATE depolar SET aktif = 0 WHERE id = ?');
            $stmt->execute([$req['params']['id']]);

            $pdo->commit();
            json_response(['mesaj' => 'Depo silindi.']);
        } catch (PDOException $e) {
            $pdo->rollBack();
            error_log('[depolar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // PUT /api/depolar/:id/restore — Admin only: Silinen depoyu geri al
    $router->put('/depolar/:id/restore', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT id, aktif FROM depolar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('Depo bulunamadı.', 404);
            }
            if ((int)$row['aktif'] === 1) {
                json_error('Bu depo zaten aktif.', 400);
            }

            $stmt = $pdo->prepare('UPDATE depolar SET aktif = 1 WHERE id = ?');
            $stmt->execute([$req['params']['id']]);

            json_response(['mesaj' => 'Depo geri alındı.']);
        } catch (PDOException $e) {
            error_log('[depolar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // GET /api/depolar — Kullanıcı veya Admin (tek handler, rol bazlı branching)
    $router->get('/depolar', function ($req) {
        $query = $req['query'];

        try {
            $pdo = get_db();

            // ── Admin değilse: kullanıcı modu ──
            if ($req['user']['rol'] !== 'admin') {
                $isletme_id = $query['isletme_id'] ?? null;
                if (!$isletme_id) {
                    json_error('isletme_id zorunludur.', 400);
                }

                $stmt = $pdo->prepare(
                    'SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1'
                );
                $stmt->execute([$req['user']['id'], $isletme_id]);
                $kiRow = $stmt->fetch();

                if (!$kiRow) {
                    json_error('Bu işletmeye erişim yetkiniz yok.', 403);
                }

                $yetkiler = json_decode($kiRow['yetkiler'], true);
                if (!($yetkiler['depo']['goruntule'] ?? false)) {
                    json_error('Depo görüntüleme yetkiniz yok.', 403);
                }

                $stmt = $pdo->prepare(
                    'SELECT id, ad, konum FROM depolar WHERE isletme_id = ? AND aktif = 1 ORDER BY ad'
                );
                $stmt->execute([$isletme_id]);
                $data = $stmt->fetchAll();

                json_response(['data' => $data ?: [], 'toplam' => count($data)]);
            }

            // ── Admin modu ──
            $isletme_id  = $query['isletme_id'] ?? null;
            $isletme_ids = $query['isletme_ids'] ?? null;
            $aktif       = $query['aktif'] ?? null;
            $q           = $query['q'] ?? null;
            $sayfa       = $query['sayfa'] ?? null;

            $where  = [];
            $params = [];

            if ($isletme_id) {
                $where[]  = 'd.isletme_id = ?';
                $params[] = $isletme_id;
            }
            if ($isletme_ids) {
                $ids = array_filter(explode(',', $isletme_ids));
                if ($ids) {
                    $placeholders = implode(',', array_fill(0, count($ids), '?'));
                    $where[] = "d.isletme_id IN ({$placeholders})";
                    array_push($params, ...$ids);
                }
            }
            if ($aktif !== null) {
                $where[]  = 'd.aktif = ?';
                $params[] = $aktif === 'true' ? 1 : 0;
            }
            if ($q) {
                $where[]  = '(d.ad LIKE ? OR d.kod LIKE ?)';
                $params[] = "%{$q}%";
                $params[] = "%{$q}%";
            }

            $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

            if (!$sayfa) {
                // backward compat — no pagination, enriched with isletmeler
                $stmt = $pdo->prepare(
                    "SELECT d.*, i.id AS isletme_id_j, i.ad AS isletme_ad, i.kod AS isletme_kod
                     FROM depolar d
                     LEFT JOIN isletmeler i ON i.id = d.isletme_id
                     {$whereClause}
                     ORDER BY i.ad ASC, d.ad ASC"
                );
                $stmt->execute($params);
                $data = $stmt->fetchAll();

                $enriched = array_map(function ($row) {
                    return [
                        'id'         => $row['id'],
                        'isletme_id' => $row['isletme_id'],
                        'ad'         => $row['ad'],
                        'kod'        => $row['kod'],
                        'konum'      => $row['konum'],
                        'aktif'      => $row['aktif'],
                        'created_at' => $row['created_at'],
                        'updated_at' => $row['updated_at'],
                        'isletmeler' => [
                            'id'  => $row['isletme_id'],
                            'ad'  => $row['isletme_ad'],
                            'kod' => $row['isletme_kod'],
                        ],
                    ];
                }, $data);

                json_response($enriched);
            }

            [$sp, $lm, $offset] = parse_pagination($query);

            // Count query
            $countStmt = $pdo->prepare("SELECT COUNT(*) AS toplam FROM depolar d {$whereClause}");
            $countStmt->execute($params);
            $toplam = (int)$countStmt->fetchColumn();

            // Data query with LEFT JOIN + sayim count subquery
            $dataStmt = $pdo->prepare(
                "SELECT d.*, i.ad AS isletme_ad, i.kod AS isletme_kod,
                   (SELECT COUNT(*) FROM sayimlar s WHERE s.depo_id = d.id AND s.durum <> 'silindi') AS sayim_sayisi
                 FROM depolar d
                 LEFT JOIN isletmeler i ON i.id = d.isletme_id
                 {$whereClause}
                 ORDER BY i.ad ASC, d.ad ASC
                 LIMIT {$lm} OFFSET {$offset}"
            );
            $dataStmt->execute($params);
            $data = $dataStmt->fetchAll();

            $enriched = array_map(function ($row) {
                return [
                    'id'           => $row['id'],
                    'isletme_id'   => $row['isletme_id'],
                    'ad'           => $row['ad'],
                    'kod'          => $row['kod'],
                    'konum'        => $row['konum'],
                    'aktif'        => $row['aktif'],
                    'created_at'   => $row['created_at'],
                    'updated_at'   => $row['updated_at'],
                    'isletmeler'   => [
                        'id'  => $row['isletme_id'],
                        'ad'  => $row['isletme_ad'],
                        'kod' => $row['isletme_kod'],
                    ],
                    'sayim_sayisi' => (int)($row['sayim_sayisi'] ?? 0),
                ];
            }, $data);

            json_response(['data' => $enriched, 'toplam' => $toplam]);
        } catch (PDOException $e) {
            error_log('[depolar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // GET /api/depolar/:id — Admin only: Detail with isletmeler JOIN
    $router->get('/depolar/:id', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare(
                "SELECT d.*, i.ad AS isletme_ad, i.kod AS isletme_kod
                 FROM depolar d
                 LEFT JOIN isletmeler i ON i.id = d.isletme_id
                 WHERE d.id = ?"
            );
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('Depo bulunamadı.', 404);
            }

            $isletme_ad  = $row['isletme_ad'];
            $isletme_kod = $row['isletme_kod'];
            unset($row['isletme_ad'], $row['isletme_kod']);

            $row['isletmeler'] = [
                'ad'  => $isletme_ad,
                'kod' => $isletme_kod,
            ];

            json_response($row);
        } catch (PDOException $e) {
            error_log('[depolar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);
}

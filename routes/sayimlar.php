<?php
/**
 * Sayımlar Routes — /api/sayimlar/*
 * En büyük route dosyası: CRUD + kalem CRUD + tamamla + topla (birleştirme)
 */

function is_toplanmis_sayim($notlar): bool {
    if (!$notlar) return false;
    $parsed = is_string($notlar) ? json_decode($notlar, true) : $notlar;
    return !empty($parsed['toplanan_sayimlar']);
}

function check_sayim_yetki(array $sayim, array $req, string $islem): bool {
    $user = $req['user'];
    if ($user['rol'] === 'admin') return true;

    $toplanmis = is_toplanmis_sayim($sayim['notlar'] ?? null);

    if (!$toplanmis && ($sayim['kullanici_id'] ?? '') !== $user['id']) {
        json_error('Bu sayıma erişim yetkiniz yok.', 403);
        return false;
    }

    $pdo = get_db();
    $stmt = $pdo->prepare('SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1');
    $stmt->execute([$user['id'], $sayim['isletme_id']]);
    $row = $stmt->fetch();

    $kat = $toplanmis ? 'toplam_sayim' : 'sayim';
    $yetkiler = $row ? json_decode($row['yetkiler'], true) : null;

    if (!$row || !($yetkiler[$kat][$islem] ?? false)) {
        $msg = $toplanmis ? "Toplanmış sayım $islem yetkiniz yok." : "Sayım $islem yetkiniz yok.";
        json_error($msg, 403);
        return false;
    }
    return true;
}

function register_sayimlar_routes(Router $router): void {

    // GET /api/sayimlar
    $router->get('/sayimlar', function($req) {
        try {
            $q = $req['query'];
            $isletmeId = $q['isletme_id'] ?? null;
            $isletmeIds = $q['isletme_ids'] ?? null;
            $depoId = $q['depo_id'] ?? null;
            $durum = $q['durum'] ?? null;
            $arama = $q['q'] ?? null;
            $toplama = $q['toplama'] ?? null;
            $user = $req['user'];

            $yetkiKat = $toplama === '1' ? 'toplam_sayim' : 'sayim';
            $pdo = get_db();

            // Yetki kontrolü
            if ($user['rol'] !== 'admin') {
                $allIds = [];
                if ($isletmeId) $allIds[] = $isletmeId;
                if ($isletmeIds) $allIds = array_merge($allIds, array_filter(explode(',', $isletmeIds)));
                foreach ($allIds as $isId) {
                    $stmt = $pdo->prepare('SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1');
                    $stmt->execute([$user['id'], $isId]);
                    $row = $stmt->fetch();
                    $yetkiler = $row ? json_decode($row['yetkiler'], true) : null;
                    if (!$row || !($yetkiler[$yetkiKat]['goruntule'] ?? false)) {
                        json_error("$yetkiKat görüntüleme yetkiniz yok.", 403);
                    }
                }
            }

            [$sayfa, $limit, $offset] = parse_pagination($q);

            $where = [];
            $params = [];

            if ($isletmeId) { $where[] = 's.isletme_id = ?'; $params[] = $isletmeId; }
            if ($isletmeIds) {
                $ids = array_filter(explode(',', $isletmeIds));
                if ($ids) { $where[] = 's.isletme_id IN (' . implode(',', array_fill(0, count($ids), '?')) . ')'; $params = array_merge($params, $ids); }
            }
            if ($depoId) { $where[] = 's.depo_id = ?'; $params[] = $depoId; }
            if ($durum) { $where[] = 's.durum = ?'; $params[] = $durum; }
            if ($arama) {
                $qClean = ltrim($arama, '#');
                $where[] = '(s.ad LIKE ? OR s.id LIKE ?)';
                $params[] = "%$arama%";
                $params[] = "$qClean%";
            }
            if ($toplama === '1') { $where[] = "s.notlar LIKE '%toplanan_sayimlar%'"; }
            if ($toplama === '0') { $where[] = "(s.notlar IS NULL OR s.notlar NOT LIKE '%toplanan_sayimlar%')"; }

            if ($user['rol'] !== 'admin') {
                if (!$isletmeId) json_error('isletme_id zorunludur.', 400);
                $where[] = 's.kullanici_id = ?';
                $params[] = $user['id'];
            }

            $whereClause = $where ? 'WHERE ' . implode(' AND ', $where) : '';

            $stmt = $pdo->prepare("SELECT COUNT(*) AS toplam FROM sayimlar s $whereClause");
            $stmt->execute($params);
            $toplam = (int)$stmt->fetch()['toplam'];

            $stmt = $pdo->prepare("SELECT s.id, s.ad, s.tarih, s.durum, s.notlar, s.created_at, s.updated_at, s.isletme_id, s.depo_id,
                d.id AS depo_id_j, d.ad AS depo_ad,
                i.id AS isletme_id_j, i.ad AS isletme_ad,
                k.id AS kullanici_id_j, k.ad_soyad AS kullanici_ad_soyad
                FROM sayimlar s
                LEFT JOIN depolar d ON d.id = s.depo_id
                LEFT JOIN isletmeler i ON i.id = s.isletme_id
                LEFT JOIN kullanicilar k ON k.id = s.kullanici_id
                $whereClause
                ORDER BY s.created_at DESC
                LIMIT $limit OFFSET $offset");
            $stmt->execute($params);
            $data = $stmt->fetchAll();

            $enriched = array_map(function($row) {
                return [
                    'id' => $row['id'], 'ad' => $row['ad'], 'tarih' => $row['tarih'], 'durum' => $row['durum'],
                    'notlar' => $row['notlar'], 'created_at' => $row['created_at'], 'updated_at' => $row['updated_at'],
                    'isletme_id' => $row['isletme_id'], 'depo_id' => $row['depo_id'],
                    'depolar' => ['id' => $row['depo_id_j'], 'ad' => $row['depo_ad']],
                    'isletmeler' => ['id' => $row['isletme_id_j'], 'ad' => $row['isletme_ad']],
                    'kullanicilar' => ['id' => $row['kullanici_id_j'], 'ad_soyad' => $row['kullanici_ad_soyad']],
                ];
            }, $data);

            json_response(['data' => $enriched, 'toplam' => $toplam]);
        } catch (\Exception $e) {
            error_log('[sayimlar GET /] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // GET /api/sayimlar/:id
    $router->get('/sayimlar/:id', function($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare("SELECT s.*,
                d.id AS depo_id_j, d.ad AS depo_ad, d.kod AS depo_kod,
                k.id AS kullanici_id_j, k.ad_soyad AS kullanici_ad_soyad,
                i.id AS isletme_id_j, i.ad AS isletme_ad, i.aktif AS isletme_aktif
                FROM sayimlar s
                LEFT JOIN depolar d ON d.id = s.depo_id
                LEFT JOIN kullanicilar k ON k.id = s.kullanici_id
                LEFT JOIN isletmeler i ON i.id = s.isletme_id
                WHERE s.id = ?");
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();

            if (!$sayim) json_error('Sayım bulunamadı.', 404);
            if (!check_sayim_yetki($sayim, $req, 'goruntule')) return;

            $stmt = $pdo->prepare("SELECT sk.id, sk.miktar, sk.birim, sk.notlar, sk.created_at,
                u.id AS urun_id, u.urun_kodu, u.urun_adi, u.isim_2, u.barkodlar, u.birim AS urun_birim, u.aktif AS urun_aktif
                FROM sayim_kalemleri sk
                LEFT JOIN isletme_urunler u ON u.id = sk.urun_id
                WHERE sk.sayim_id = ?
                ORDER BY sk.created_at");
            $stmt->execute([$req['params']['id']]);
            $kalemler = $stmt->fetchAll();

            $result = [
                'id' => $sayim['id'], 'ad' => $sayim['ad'], 'tarih' => $sayim['tarih'], 'durum' => $sayim['durum'],
                'notlar' => $sayim['notlar'], 'kisiler' => $sayim['kisiler'] ?? null,
                'isletme_id' => $sayim['isletme_id'], 'depo_id' => $sayim['depo_id'], 'kullanici_id' => $sayim['kullanici_id'],
                'created_at' => $sayim['created_at'], 'updated_at' => $sayim['updated_at'],
                'depolar' => ['id' => $sayim['depo_id_j'], 'ad' => $sayim['depo_ad'], 'kod' => $sayim['depo_kod']],
                'kullanicilar' => ['id' => $sayim['kullanici_id_j'], 'ad_soyad' => $sayim['kullanici_ad_soyad']],
                'isletmeler' => ['id' => $sayim['isletme_id_j'], 'ad' => $sayim['isletme_ad'], 'aktif' => (bool)(int)($sayim['isletme_aktif'] ?? 0)],
                'sayim_kalemleri' => array_map(function($k) {
                    return [
                        'id' => $k['id'], 'miktar' => $k['miktar'], 'birim' => $k['birim'],
                        'notlar' => $k['notlar'], 'created_at' => $k['created_at'],
                        'isletme_urunler' => $k['urun_id'] ? [
                            'id' => $k['urun_id'], 'urun_kodu' => $k['urun_kodu'], 'urun_adi' => $k['urun_adi'],
                            'isim_2' => $k['isim_2'], 'barkodlar' => $k['barkodlar'], 'birim' => $k['urun_birim'],
                            'aktif' => (bool)(int)($k['urun_aktif'] ?? 0),
                        ] : null,
                    ];
                }, $kalemler),
            ];

            json_response($result);
        } catch (\Exception $e) {
            error_log('[sayimlar GET /:id] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // DELETE /api/sayimlar/:id
    $router->delete('/sayimlar/:id', function($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT kullanici_id, durum, isletme_id, notlar FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();

            if (!$sayim) json_error('Sayım bulunamadı.', 404);

            $isToplanmis = is_toplanmis_sayim($sayim['notlar'] ?? null);

            if ($req['user']['rol'] !== 'admin') {
                if (!$isToplanmis && $sayim['kullanici_id'] !== $req['user']['id']) {
                    json_error('Bu sayımı silme yetkiniz yok.', 403);
                }
                $stmt2 = $pdo->prepare('SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1');
                $stmt2->execute([$req['user']['id'], $sayim['isletme_id']]);
                $kiRow = $stmt2->fetch();
                $yetkiKat = $isToplanmis ? 'toplam_sayim' : 'sayim';
                $yetkiler = $kiRow ? json_decode($kiRow['yetkiler'], true) : null;
                if (!$kiRow || !($yetkiler[$yetkiKat]['sil'] ?? false)) {
                    json_error($isToplanmis ? 'Toplanmış sayım silme yetkiniz yok.' : 'Sayım silme yetkiniz yok.', 403);
                }
            }

            if ($sayim['durum'] === 'tamamlandi' && !$isToplanmis) {
                json_error('Tamamlanmış sayım silinemez.', 400);
            }

            $stmt = $pdo->prepare("UPDATE sayimlar SET durum = 'silindi' WHERE id = ?");
            $stmt->execute([$req['params']['id']]);
            json_response(['mesaj' => 'Sayım silindi.']);
        } catch (\Exception $e) {
            error_log('[sayimlar DELETE /:id] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // PUT /api/sayimlar/:id/restore
    $router->put('/sayimlar/:id/restore', function($req) {
        if ($req['user']['rol'] !== 'admin') json_error('Yalnızca admin bu işlemi yapabilir.', 403);
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT id, durum FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();
            if (!$row) json_error('Sayım bulunamadı.', 404);
            if ($row['durum'] !== 'silindi') json_error('Bu sayım silinmiş durumda değil.', 400);
            $pdo->prepare("UPDATE sayimlar SET durum = 'devam' WHERE id = ?")->execute([$req['params']['id']]);
            json_response(['mesaj' => 'Sayım geri alındı.']);
        } catch (\Exception $e) {
            error_log('[sayimlar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // POST /api/sayimlar
    $router->post('/sayimlar', function($req) {
        $body = $req['body'];
        $isletmeId = $body['isletme_id'] ?? null;
        $depoId = $body['depo_id'] ?? null;
        $ad = $body['ad'] ?? null;
        $tarih = $body['tarih'] ?? date('Y-m-d');
        $notlar = $body['notlar'] ?? null;

        if (!$isletmeId || !$depoId || !$ad) {
            json_error('isletme_id, depo_id ve ad zorunludur.', 400);
        }

        $pdo = get_db();
        $id = uuid_v4();
        try {
            $stmt = $pdo->prepare('INSERT INTO sayimlar (id, isletme_id, depo_id, kullanici_id, ad, tarih, notlar) VALUES (?, ?, ?, ?, ?, ?, ?)');
            $stmt->execute([$id, $isletmeId, $depoId, $req['user']['id'], $ad, $tarih, $notlar]);

            $stmt = $pdo->prepare('SELECT * FROM sayimlar WHERE id = ?');
            $stmt->execute([$id]);
            json_response($stmt->fetch(), 201);
        } catch (\Exception $e) {
            error_log('[sayimlar POST /] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), yetki_guard('sayim', 'ekle', 'body')]);

    // PUT /api/sayimlar/:id
    $router->put('/sayimlar/:id', function($req) {
        try {
            $body = $req['body'];
            $pdo = get_db();

            $stmt = $pdo->prepare('SELECT kullanici_id, isletme_id, durum, notlar, updated_at FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();

            if (!$sayim) json_error('Sayım bulunamadı.', 404);

            $isToplanmis = is_toplanmis_sayim($sayim['notlar'] ?? null);

            if ($req['user']['rol'] !== 'admin') {
                if (!$isToplanmis && $sayim['kullanici_id'] !== $req['user']['id']) {
                    json_error('Bu sayımı düzenleme yetkiniz yok.', 403);
                }
                $yetkiKat = $isToplanmis ? 'toplam_sayim' : 'sayim';
                $stmt2 = $pdo->prepare('SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1');
                $stmt2->execute([$req['user']['id'], $sayim['isletme_id']]);
                $kiRow = $stmt2->fetch();
                $yetkiler = $kiRow ? json_decode($kiRow['yetkiler'], true) : null;
                if (!$kiRow || !($yetkiler[$yetkiKat]['duzenle'] ?? false)) {
                    $label = $isToplanmis ? 'Toplanmış sayım' : 'Sayım';
                    json_error("$label düzenleme yetkiniz yok.", 403);
                }
            }

            $depoId = $body['depo_id'] ?? null;
            $ad = $body['ad'] ?? null;
            $kisiler = $body['kisiler'] ?? null;

            if ($sayim['durum'] !== 'devam' && ($depoId !== null || $kisiler !== null)) {
                json_error('Tamamlanmış sayımda sadece isim değiştirilebilir.', 400);
            }

            $fields = [];
            $params = [];
            if ($depoId !== null) { $fields[] = 'depo_id = ?'; $params[] = $depoId; }
            if ($ad !== null) { $fields[] = 'ad = ?'; $params[] = $ad; }
            if ($kisiler !== null) { $fields[] = 'kisiler = ?'; $params[] = json_encode($kisiler); }

            if (empty($fields)) {
                $stmt = $pdo->prepare('SELECT * FROM sayimlar WHERE id = ?');
                $stmt->execute([$req['params']['id']]);
                json_response($stmt->fetch());
                return;
            }

            $fields[] = 'updated_at = NOW()';
            $params[] = $req['params']['id'];

            $clientUpdatedAt = $body['updated_at'] ?? null;
            if ($clientUpdatedAt) {
                $d = strtotime($clientUpdatedAt);
                if ($d) {
                    $normalized = date('Y-m-d H:i:s', $d);
                    $params[] = $normalized;
                    $whereClause = 'WHERE id = ? AND updated_at = ?';
                } else {
                    $whereClause = 'WHERE id = ?';
                }
            } else {
                $whereClause = 'WHERE id = ?';
            }

            $stmt = $pdo->prepare("UPDATE sayimlar SET " . implode(', ', $fields) . " $whereClause");
            $stmt->execute($params);

            if ($stmt->rowCount() === 0 && $clientUpdatedAt) {
                json_error('Bu kayıt başka biri tarafından güncellendi. Lütfen sayfayı yenileyip tekrar deneyin.', 409);
            }

            $stmt = $pdo->prepare('SELECT * FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            json_response($stmt->fetch());
        } catch (\Exception $e) {
            error_log('[sayimlar PUT /:id] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // PUT /api/sayimlar/:id/tamamla
    $router->put('/sayimlar/:id/tamamla', function($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT kullanici_id, durum, isletme_id, notlar FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();

            if (!$sayim) json_error('Sayım bulunamadı.', 404);
            if (!check_sayim_yetki($sayim, $req, 'duzenle')) return;
            if ($sayim['durum'] !== 'devam') json_error('Sadece devam eden sayımlar tamamlanabilir.', 400);

            $pdo->prepare("UPDATE sayimlar SET durum = 'tamamlandi' WHERE id = ?")->execute([$req['params']['id']]);
            $stmt = $pdo->prepare('SELECT * FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            json_response($stmt->fetch());
        } catch (\Exception $e) {
            error_log('[sayimlar PUT /:id/tamamla] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // PUT /api/sayimlar/:id/yeniden-ac
    $router->put('/sayimlar/:id/yeniden-ac', function($req) {
        if ($req['user']['rol'] !== 'admin') json_error('Sayımı yeniden açma yetkisi yalnızca adminlere aittir.', 403);
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT durum FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();
            if (!$row) json_error('Sayım bulunamadı.', 404);
            if ($row['durum'] === 'devam') json_error('Sayım zaten açık durumda.', 400);
            $pdo->prepare("UPDATE sayimlar SET durum = 'devam' WHERE id = ?")->execute([$req['params']['id']]);
            $stmt = $pdo->prepare('SELECT * FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            json_response($stmt->fetch());
        } catch (\Exception $e) {
            error_log('[sayimlar] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // GET /api/sayimlar/:id/kalemler
    $router->get('/sayimlar/:id/kalemler', function($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT kullanici_id, isletme_id, notlar FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();
            if (!$sayim) json_error('Sayım bulunamadı.', 404);
            if (!check_sayim_yetki($sayim, $req, 'goruntule')) return;

            $stmt = $pdo->prepare("SELECT sk.*,
                u.id AS urun_id_j, u.urun_kodu, u.urun_adi, u.isim_2, u.barkodlar, u.birim AS urun_birim, u.aktif AS urun_aktif
                FROM sayim_kalemleri sk
                LEFT JOIN isletme_urunler u ON u.id = sk.urun_id
                WHERE sk.sayim_id = ?
                ORDER BY sk.created_at");
            $stmt->execute([$req['params']['id']]);
            $data = $stmt->fetchAll();

            $enriched = array_map(function($row) {
                return [
                    'id' => $row['id'], 'sayim_id' => $row['sayim_id'], 'urun_id' => $row['urun_id'],
                    'miktar' => $row['miktar'], 'birim' => $row['birim'], 'notlar' => $row['notlar'], 'created_at' => $row['created_at'],
                    'isletme_urunler' => $row['urun_id_j'] ? [
                        'id' => $row['urun_id_j'], 'urun_kodu' => $row['urun_kodu'], 'urun_adi' => $row['urun_adi'],
                        'isim_2' => $row['isim_2'], 'barkodlar' => $row['barkodlar'], 'birim' => $row['urun_birim'],
                        'aktif' => (bool)(int)($row['urun_aktif'] ?? 0),
                    ] : null,
                ];
            }, $data);

            json_response($enriched);
        } catch (\Exception $e) {
            error_log('[sayimlar GET /:id/kalemler] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // POST /api/sayimlar/:id/kalem
    $router->post('/sayimlar/:id/kalem', function($req) {
        $body = $req['body'];
        $urunId = $body['urun_id'] ?? null;
        $miktar = $body['miktar'] ?? null;
        $birim = $body['birim'] ?? null;
        $notlar = $body['notlar'] ?? null;

        if (!$urunId || $miktar === null) json_error('urun_id ve miktar zorunludur.', 400);
        if (!is_numeric($miktar)) json_error('miktar sayısal bir değer olmalıdır.', 400);

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            $stmt = $pdo->prepare('SELECT kullanici_id, isletme_id, durum, notlar FROM sayimlar WHERE id = ? FOR UPDATE');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();

            if (!$sayim) { $pdo->rollBack(); json_error('Sayım bulunamadı.', 404); }
            if (!check_sayim_yetki($sayim, $req, 'duzenle')) { $pdo->rollBack(); return; }
            if ($sayim['durum'] !== 'devam') { $pdo->rollBack(); json_error('Tamamlanmış sayıma kalem eklenemez.', 400); }

            $stmt = $pdo->prepare('SELECT isletme_id FROM isletme_urunler WHERE id = ?');
            $stmt->execute([$urunId]);
            $urun = $stmt->fetch();
            if (!$urun) { $pdo->rollBack(); json_error('Ürün bulunamadı.', 404); }
            if ($urun['isletme_id'] !== $sayim['isletme_id']) { $pdo->rollBack(); json_error('Bu ürün bu işletmeye ait değil.', 400); }

            $id = uuid_v4();
            $stmt = $pdo->prepare('INSERT INTO sayim_kalemleri (id, sayim_id, urun_id, miktar, birim, notlar) VALUES (?, ?, ?, ?, ?, ?)');
            $stmt->execute([$id, $req['params']['id'], $urunId, $miktar, $birim, $notlar]);

            $pdo->commit();

            $stmt = $pdo->prepare("SELECT sk.*, u.id AS urun_id_j, u.urun_kodu, u.urun_adi
                FROM sayim_kalemleri sk LEFT JOIN isletme_urunler u ON u.id = sk.urun_id WHERE sk.id = ?");
            $stmt->execute([$id]);
            $row = $stmt->fetch();

            json_response([
                'id' => $row['id'], 'sayim_id' => $row['sayim_id'], 'urun_id' => $row['urun_id'],
                'miktar' => $row['miktar'], 'birim' => $row['birim'], 'notlar' => $row['notlar'], 'created_at' => $row['created_at'],
                'isletme_urunler' => $row['urun_id_j'] ? ['id' => $row['urun_id_j'], 'urun_kodu' => $row['urun_kodu'], 'urun_adi' => $row['urun_adi']] : null,
            ], 201);
        } catch (\Exception $e) {
            $pdo->rollBack();
            error_log('[sayimlar POST /:id/kalem] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // PUT /api/sayimlar/:id/kalem/:kalem_id
    $router->put('/sayimlar/:id/kalem/:kalem_id', function($req) {
        try {
            $body = $req['body'];
            $pdo = get_db();

            $stmt = $pdo->prepare('SELECT kullanici_id, isletme_id, durum, notlar FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();
            if (!$sayim) json_error('Sayım bulunamadı.', 404);
            if (!check_sayim_yetki($sayim, $req, 'duzenle')) return;
            if ($sayim['durum'] !== 'devam') json_error('Tamamlanmış sayım düzenlenemez.', 400);

            $updates = [];
            $values = [];
            if (isset($body['miktar'])) { $updates[] = 'miktar = ?'; $values[] = $body['miktar']; }
            if (isset($body['birim'])) { $updates[] = 'birim = ?'; $values[] = $body['birim']; }
            if (array_key_exists('notlar', $body)) { $updates[] = 'notlar = ?'; $values[] = $body['notlar']; }
            if (empty($updates)) json_error('Güncellenecek alan yok.', 400);

            $values[] = $req['params']['kalem_id'];
            $values[] = $req['params']['id'];

            $pdo->prepare("UPDATE sayim_kalemleri SET " . implode(', ', $updates) . " WHERE id = ? AND sayim_id = ?")->execute($values);

            $stmt = $pdo->prepare('SELECT * FROM sayim_kalemleri WHERE id = ? AND sayim_id = ?');
            $stmt->execute([$req['params']['kalem_id'], $req['params']['id']]);
            $row = $stmt->fetch();
            if (!$row) json_error('Kalem bulunamadı.', 404);
            json_response($row);
        } catch (\Exception $e) {
            error_log('[sayimlar PUT /:id/kalem/:kalem_id] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // DELETE /api/sayimlar/:id/kalem/:kalem_id
    $router->delete('/sayimlar/:id/kalem/:kalem_id', function($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT kullanici_id, isletme_id, durum, notlar FROM sayimlar WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $sayim = $stmt->fetch();
            if (!$sayim) json_error('Sayım bulunamadı.', 404);
            if (!check_sayim_yetki($sayim, $req, 'duzenle')) return;
            if ($sayim['durum'] !== 'devam') json_error('Tamamlanmış sayımdan kalem silinemez.', 400);

            $pdo->prepare('DELETE FROM sayim_kalemleri WHERE id = ? AND sayim_id = ?')
                ->execute([$req['params']['kalem_id'], $req['params']['id']]);

            json_response(['mesaj' => 'Kalem silindi.']);
        } catch (\Exception $e) {
            error_log('[sayimlar DELETE /:id/kalem/:kalem_id] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard()]);

    // POST /api/sayimlar/topla
    $router->post('/sayimlar/topla', function($req) {
        $body = $req['body'];
        $sayimIds = $body['sayim_ids'] ?? [];
        $ad = $body['ad'] ?? '';
        $isletmeId = $body['isletme_id'] ?? null;

        if (!is_array($sayimIds) || count($sayimIds) < 2) json_error('En az 2 sayım seçilmelidir.', 400);
        if (!trim($ad)) json_error('Toplanmış sayım adı zorunludur.', 400);
        if (!$isletmeId) json_error('isletme_id zorunludur.', 400);

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            $placeholders = implode(',', array_fill(0, count($sayimIds), '?'));
            $stmt = $pdo->prepare("SELECT s.id, s.isletme_id, s.depo_id, s.kullanici_id, s.ad, s.tarih, s.durum, d.ad AS depo_ad
                FROM sayimlar s LEFT JOIN depolar d ON s.depo_id = d.id
                WHERE s.id IN ($placeholders) AND s.durum = 'tamamlandi' FOR UPDATE");
            $stmt->execute($sayimIds);
            $sayimlar = $stmt->fetchAll();

            if (count($sayimlar) !== count($sayimIds)) {
                $pdo->rollBack();
                json_error('Sadece tamamlanmış sayımlar birleştirilebilir.', 400);
            }

            $ilkIsletmeId = $sayimlar[0]['isletme_id'];
            foreach ($sayimlar as $s) {
                if ($s['isletme_id'] !== $ilkIsletmeId) {
                    $pdo->rollBack();
                    json_error('Tüm sayımlar aynı işletmeye ait olmalıdır.', 400);
                }
            }

            if ($req['user']['rol'] !== 'admin') {
                foreach ($sayimlar as $s) {
                    if ($s['kullanici_id'] !== $req['user']['id']) {
                        $pdo->rollBack();
                        json_error('Sadece kendi sayımlarınızı toplayabilirsiniz.', 403);
                    }
                }
            }

            $stmt = $pdo->prepare("SELECT sk.sayim_id, sk.urun_id, sk.miktar, sk.birim
                FROM sayim_kalemleri sk WHERE sk.sayim_id IN ($placeholders) FOR UPDATE");
            $stmt->execute($sayimIds);
            $kalemler = $stmt->fetchAll();

            $toplamMap = [];
            foreach ($kalemler as $k) {
                $uid = $k['urun_id'];
                if (!isset($toplamMap[$uid])) {
                    $toplamMap[$uid] = ['miktar' => 0, 'birim' => $k['birim']];
                }
                $toplamMap[$uid]['miktar'] += (float)$k['miktar'];
            }

            $depoId = $sayimlar[0]['depo_id'];
            $notlar = json_encode([
                'toplanan_sayimlar' => array_map(fn($s) => [
                    'id' => $s['id'], 'ad' => $s['ad'], 'tarih' => $s['tarih'], 'depo' => $s['depo_ad']
                ], $sayimlar)
            ], JSON_UNESCAPED_UNICODE);

            $yeniId = uuid_v4();
            $stmt = $pdo->prepare("INSERT INTO sayimlar (id, isletme_id, depo_id, kullanici_id, ad, tarih, durum, notlar) VALUES (?, ?, ?, ?, ?, ?, 'tamamlandi', ?)");
            $stmt->execute([$yeniId, $isletmeId, $depoId, $req['user']['id'], trim($ad), date('Y-m-d'), $notlar]);

            foreach ($toplamMap as $urunId => $data) {
                $kalemId = uuid_v4();
                $pdo->prepare('INSERT INTO sayim_kalemleri (id, sayim_id, urun_id, miktar, birim) VALUES (?, ?, ?, ?, ?)')
                    ->execute([$kalemId, $yeniId, $urunId, $data['miktar'], $data['birim']]);
            }

            $pdo->commit();

            $stmt = $pdo->prepare('SELECT * FROM sayimlar WHERE id = ?');
            $stmt->execute([$yeniId]);
            json_response($stmt->fetch(), 201);
        } catch (\Exception $e) {
            $pdo->rollBack();
            error_log('[sayimlar POST /topla] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), yetki_guard('toplam_sayim', 'ekle', 'body')]);
}

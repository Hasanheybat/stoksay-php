<?php
/**
 * Roller Routes — /api/roller/*
 * Tüm route'lar auth + admin gerektirir
 */

function register_roller_routes(Router $router): void {

    // GET /api/roller — Tüm rolleri listele
    $router->get('/roller', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->query('SELECT * FROM roller ORDER BY sistem DESC, created_at ASC');
            $rows = $stmt->fetchAll();

            json_response($rows ?: []);
        } catch (PDOException $e) {
            error_log('[roller] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // POST /api/roller — Yeni özel rol oluştur
    $router->post('/roller', function ($req) {
        $body = $req['body'];
        $ad       = $body['ad'] ?? null;
        $yetkiler = $body['yetkiler'] ?? null;

        if (!$ad || !trim($ad)) {
            json_error('Rol adı zorunludur.', 400);
        }

        $varsayilanYetkiler = [
            'urun'         => ['goruntule' => true,  'ekle' => false, 'duzenle' => false, 'sil' => false],
            'depo'         => ['goruntule' => true,  'ekle' => false, 'duzenle' => false, 'sil' => false],
            'sayim'        => ['goruntule' => true,  'ekle' => true,  'duzenle' => false, 'sil' => false],
            'toplam_sayim' => ['goruntule' => false, 'ekle' => false, 'duzenle' => false, 'sil' => false],
        ];

        try {
            $pdo = get_db();
            $id = uuid_v4();

            $yetkilerJson = json_encode($yetkiler ?: $varsayilanYetkiler, JSON_UNESCAPED_UNICODE);

            $stmt = $pdo->prepare('INSERT INTO roller (id, ad, yetkiler, sistem) VALUES (?, ?, ?, 0)');
            $stmt->execute([$id, trim($ad), $yetkilerJson]);

            $stmt = $pdo->prepare('SELECT * FROM roller WHERE id = ?');
            $stmt->execute([$id]);
            $row = $stmt->fetch();

            json_response($row, 201);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu rol adı zaten mevcut.', 409);
            }
            error_log('[roller] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // PUT /api/roller/:id — Rol güncelle (yetki matrisi + ad)
    $router->put('/roller/:id', function ($req) {
        $body = $req['body'];
        $ad       = array_key_exists('ad', $body) ? $body['ad'] : null;
        $yetkiler = array_key_exists('yetkiler', $body) ? $body['yetkiler'] : null;

        $hasAd       = array_key_exists('ad', $body);
        $hasYetkiler = array_key_exists('yetkiler', $body);

        if (!$hasAd && !$hasYetkiler) {
            json_error('Güncellenecek alan yok.', 400);
        }

        try {
            $pdo = get_db();

            // Sistem rollerinin adı değiştirilemez
            $adToUpdate = null;
            if ($hasAd) {
                $stmt = $pdo->prepare('SELECT sistem FROM roller WHERE id = ?');
                $stmt->execute([$req['params']['id']]);
                $mevcutRow = $stmt->fetch();

                if ($mevcutRow && (int)$mevcutRow['sistem']) {
                    // Sistem rolü: ad güncellenmez
                    $adToUpdate = null;
                } else {
                    $adToUpdate = trim($ad);
                }
            }

            $fields = [];
            $params = [];

            if ($adToUpdate !== null) {
                $fields[] = 'ad = ?';
                $params[] = $adToUpdate;
            }
            if ($hasYetkiler) {
                $fields[] = 'yetkiler = ?';
                $params[] = json_encode($yetkiler, JSON_UNESCAPED_UNICODE);
            }

            if ($fields) {
                $params[] = $req['params']['id'];
                $stmt = $pdo->prepare('UPDATE roller SET ' . implode(', ', $fields) . ' WHERE id = ?');
                $stmt->execute($params);
            }

            // Yetkiler değiştiyse, bu role atanmış tüm kullanici_isletme kayıtlarını da güncelle
            if ($hasYetkiler) {
                $stmt = $pdo->prepare('UPDATE kullanici_isletme SET yetkiler = ? WHERE rol_id = ?');
                $stmt->execute([json_encode($yetkiler, JSON_UNESCAPED_UNICODE), $req['params']['id']]);
            }

            $stmt = $pdo->prepare('SELECT * FROM roller WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) {
                json_error('Rol bulunamadı.', 404);
            }

            json_response($row);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu rol adı zaten mevcut.', 409);
            }
            error_log('[roller] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // GET /api/roller/:id/atanmislar — Bu role atanmış kullanıcıları getir
    $router->get('/roller/:id/atanmislar', function ($req) {
        try {
            $pdo = get_db();
            $stmt = $pdo->prepare(
                "SELECT ki.id as ki_id, ki.kullanici_id, ki.isletme_id, k.ad_soyad, k.email, i.ad as isletme_ad
                 FROM kullanici_isletme ki
                 JOIN kullanicilar k ON ki.kullanici_id = k.id
                 JOIN isletmeler i ON ki.isletme_id = i.id
                 WHERE ki.rol_id = ? AND ki.aktif = 1"
            );
            $stmt->execute([$req['params']['id']]);
            $rows = $stmt->fetchAll();

            json_response($rows ?: []);
        } catch (PDOException $e) {
            error_log('[roller] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // DELETE /api/roller/:id — Rol sil (sadece özel roller)
    // Body: { atamalar: [{ ki_id, yeni_rol_id }] } — isteğe bağlı yeniden atama
    $router->delete('/roller/:id', function ($req) {
        try {
            $pdo = get_db();

            // Sistem rolü olup olmadığını kontrol et
            $stmt = $pdo->prepare('SELECT sistem, ad FROM roller WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $rolRow = $stmt->fetch();

            if (!$rolRow) {
                json_error('Rol bulunamadı.', 404);
            }

            if ((int)$rolRow['sistem']) {
                json_error('"' . $rolRow['ad'] . '" sistem rolü silinemez.', 403);
            }

            $atamalar = $req['body']['atamalar'] ?? [];
            $bosYetkiler = json_encode([
                'urun'         => ['goruntule' => false, 'ekle' => false, 'duzenle' => false, 'sil' => false],
                'depo'         => ['goruntule' => false, 'ekle' => false, 'duzenle' => false, 'sil' => false],
                'sayim'        => ['goruntule' => false, 'ekle' => false, 'duzenle' => false, 'sil' => false],
                'toplam_sayim' => ['goruntule' => false, 'ekle' => false, 'duzenle' => false, 'sil' => false],
            ], JSON_UNESCAPED_UNICODE);

            // Transaction ile atomik işlem
            $pdo->beginTransaction();
            try {
                // Yeniden atama yapılanları işle
                foreach ($atamalar as $atama) {
                    $ki_id      = $atama['ki_id'] ?? null;
                    $yeni_rol_id = $atama['yeni_rol_id'] ?? null;

                    if (!$ki_id || !$yeni_rol_id) continue;

                    $stmt = $pdo->prepare('SELECT yetkiler FROM roller WHERE id = ?');
                    $stmt->execute([$yeni_rol_id]);
                    $yeniRolRow = $stmt->fetch();

                    if ($yeniRolRow) {
                        $stmt = $pdo->prepare(
                            'UPDATE kullanici_isletme SET rol_id = ?, yetkiler = ? WHERE id = ?'
                        );
                        $stmt->execute([$yeni_rol_id, $yeniRolRow['yetkiler'], $ki_id]);
                    }
                }

                // Yeniden atama yapılmayan kullanıcıların yetkilerini sıfırla
                $stmt = $pdo->prepare(
                    'UPDATE kullanici_isletme SET rol_id = NULL, yetkiler = ? WHERE rol_id = ?'
                );
                $stmt->execute([$bosYetkiler, $req['params']['id']]);

                // Rolü sil
                $stmt = $pdo->prepare('DELETE FROM roller WHERE id = ?');
                $stmt->execute([$req['params']['id']]);

                $pdo->commit();
            } catch (PDOException $txErr) {
                $pdo->rollBack();
                throw $txErr;
            }

            json_response(['mesaj' => 'Rol silindi.']);
        } catch (PDOException $e) {
            error_log('[roller] ' . $e->getMessage());
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), admin_guard()]);
}

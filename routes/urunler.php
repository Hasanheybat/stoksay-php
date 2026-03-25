<?php
/**
 * Urunler Routes — /api/urunler/*
 * Node.js Express route conversion (670 lines)
 */

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\IOFactory;

/* ── Yetki kontrol yardimcisi (isletme_id yoksa DB'den ceker) ── */
function checkUrunYetki(array $req, string $islem): bool {
    $user = $req['user'];
    if ($user['rol'] === 'admin') return true;

    $pdo = get_db();
    $stmt = $pdo->prepare('SELECT isletme_id FROM isletme_urunler WHERE id = ?');
    $stmt->execute([$req['params']['id']]);
    $urun = $stmt->fetch();

    if (!$urun) {
        json_error('Urun bulunamadi.', 404);
        return false; // unreachable, json_error exits
    }

    $stmt = $pdo->prepare(
        'SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1'
    );
    $stmt->execute([$user['id'], $urun['isletme_id']]);
    $row = $stmt->fetch();

    if (!$row) {
        json_error('Bu isletmeye erisim yetkiniz yok.', 403);
        return false;
    }

    $yetkiler = json_decode($row['yetkiler'], true);
    if (!($yetkiler['urun'][$islem] ?? false)) {
        json_error("Urun $islem yetkiniz yok.", 403);
        return false;
    }

    return true;
}

/**
 * Ayni isletmede baska bir urunde bu barkod var mi kontrol et
 * Transaction icindeyse FOR UPDATE ile satirlari kilitle
 */
function barkodBenzersizKontrol(PDO $db, string $isletmeId, array $barkodlar, ?string $haricUrunId = null): ?array {
    if (empty($barkodlar)) return null;

    // Check if we are in a transaction — if so, use FOR UPDATE
    $inTransaction = $db->inTransaction();
    $lockSuffix = $inTransaction ? ' FOR UPDATE' : '';

    $stmt = $db->prepare(
        "SELECT id, urun_adi, barkodlar FROM isletme_urunler WHERE isletme_id = ? AND aktif = 1{$lockSuffix}"
    );
    $stmt->execute([$isletmeId]);
    $rows = $stmt->fetchAll();

    foreach ($rows as $row) {
        if ($haricUrunId && (string)$row['id'] === (string)$haricUrunId) continue;
        $mevcutBarkodlar = array_filter(array_map('trim', explode(',', $row['barkodlar'] ?? '')));
        foreach ($barkodlar as $barkod) {
            if (in_array($barkod, $mevcutBarkodlar, true)) {
                return ['barkod' => $barkod, 'urunAdi' => $row['urun_adi']];
            }
        }
    }

    return null;
}

function register_urunler_routes(Router $router): void {

    // ═══════════════════════════════════════════════════════════════
    //  KULLANICI ERISIMLERI (auth only, admin oncesi)
    // ═══════════════════════════════════════════════════════════════

    // 1. PUT /urunler/:id — Urun guncelle
    $router->put('/urunler/:id', function (array $req) {
        if (!checkUrunYetki($req, 'duzenle')) return;

        $body = $req['body'];
        $urunAdi = $body['urun_adi'] ?? null;
        $urunKodu = $body['urun_kodu'] ?? null;
        $isim2 = $body['isim_2'] ?? '';
        $barkodlar = $body['barkodlar'] ?? [];
        $birim = $body['birim'] ?? null;

        if (!$urunAdi || !trim($urunAdi)) {
            json_error('Isim 1 (sayim ismi) bos olamaz.', 400);
        }

        $kodGuncelle = ($urunKodu && trim($urunKodu)) ? trim($urunKodu) : null;

        // Parse barkodlar — array or comma-separated string
        if (is_array($barkodlar)) {
            $barkodArr = array_values(array_filter(array_map('trim', $barkodlar)));
        } elseif (is_string($barkodlar)) {
            $barkodArr = array_values(array_filter(array_map('trim', explode(',', $barkodlar))));
        } else {
            $barkodArr = [];
        }
        $barkodStr = implode(',', $barkodArr);

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            // Lock the row
            $stmt = $pdo->prepare('SELECT isletme_id FROM isletme_urunler WHERE id = ? FOR UPDATE');
            $stmt->execute([$req['params']['id']]);
            $urunRow = $stmt->fetch();

            if ($urunRow && count($barkodArr) > 0) {
                $cakisan = barkodBenzersizKontrol($pdo, $urunRow['isletme_id'], $barkodArr, $req['params']['id']);
                if ($cakisan) {
                    $pdo->rollBack();
                    json_error("\"{$cakisan['barkod']}\" barkodu \"{$cakisan['urunAdi']}\" urununne zaten tanimli.", 409);
                }
            }

            // urun_kodu bossa mevcut degeri koru
            if (!$kodGuncelle) {
                $stmt = $pdo->prepare('SELECT urun_kodu FROM isletme_urunler WHERE id = ?');
                $stmt->execute([$req['params']['id']]);
                $mevcutRow = $stmt->fetch();
                $finalKod = $mevcutRow['urun_kodu'] ?? '';
            } else {
                $finalKod = $kodGuncelle;
            }

            $stmt = $pdo->prepare(
                "UPDATE isletme_urunler SET
                    urun_adi = ?, urun_kodu = ?, isim_2 = ?, barkodlar = ?, birim = ?,
                    son_guncelleme = NOW(), guncelleme_kaynagi = 'kullanici',
                    kullanici_guncelledi = 1, guncelleyen_kullanici_id = ?
                WHERE id = ?"
            );
            $stmt->execute([
                trim($urunAdi),
                $finalKod,
                trim($isim2),
                $barkodStr,
                $birim ?: null,
                $req['user']['id'],
                $req['params']['id'],
            ]);

            $pdo->commit();

            $stmt = $pdo->prepare('SELECT * FROM isletme_urunler WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();
            if (!$row) json_error('Urun bulunamadi.', 404);

            json_response($row);
        } catch (\PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            error_log('[PUT /urunler/:id] ' . $e->getMessage());
            json_error('Sunucu hatasi.', 500);
        }
    }, [auth_guard()]);

    // 2. POST /urunler — Yeni urun ekle
    $router->post('/urunler', function (array $req) {
        $body = $req['body'];
        $isletmeId = $body['isletme_id'] ?? null;
        $urunKodu = $body['urun_kodu'] ?? null;
        $urunAdi = $body['urun_adi'] ?? null;
        $isim2 = $body['isim_2'] ?? '';
        $birim = $body['birim'] ?? 'ADET';
        $barkodlar = $body['barkodlar'] ?? [];
        $kategori = $body['kategori'] ?? null;

        if (!$isletmeId || !$urunAdi || !trim($urunAdi)) {
            json_error('isletme_id ve urun_adi zorunludur.', 400);
        }

        // Parse barkodlar
        if (is_array($barkodlar)) {
            $barkodArr = array_values(array_filter(array_map('trim', $barkodlar)));
        } elseif (is_string($barkodlar)) {
            $barkodArr = array_values(array_filter(array_map('trim', explode(',', $barkodlar))));
        } else {
            $barkodArr = [];
        }
        $barkodStr = implode(',', $barkodArr);

        $id = uuid_v4();
        $kod = ($urunKodu && trim($urunKodu)) ? trim($urunKodu) : 'STK-' . substr($id, 0, 8);

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            if (count($barkodArr) > 0) {
                $cakisan = barkodBenzersizKontrol($pdo, $isletmeId, $barkodArr, null);
                if ($cakisan) {
                    $pdo->rollBack();
                    json_error("\"{$cakisan['barkod']}\" barkodu \"{$cakisan['urunAdi']}\" urununne zaten tanimli.", 409);
                }
            }

            $stmt = $pdo->prepare(
                "INSERT INTO isletme_urunler
                    (id, isletme_id, urun_kodu, urun_adi, isim_2, birim, barkodlar, kategori, guncelleme_kaynagi, guncelleyen_kullanici_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'kullanici', ?)"
            );
            $stmt->execute([
                $id,
                $isletmeId,
                $kod,
                trim($urunAdi),
                trim($isim2),
                $birim ?: 'ADET',
                $barkodStr,
                $kategori ?: null,
                $req['user']['id'],
            ]);

            $pdo->commit();

            $stmt = $pdo->prepare('SELECT * FROM isletme_urunler WHERE id = ?');
            $stmt->execute([$id]);
            $row = $stmt->fetch();

            json_response($row, 201);
        } catch (\PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            if (isset($e->errorInfo[1]) && $e->errorInfo[1] == 1062) {
                json_error('Bu urun kodu bu isletmede zaten var.', 409);
            }
            error_log('[POST /urunler] ' . $e->getMessage());
            json_error('Sunucu hatasi.', 500);
        }
    }, [auth_guard(), yetki_guard('urun', 'ekle', 'body')]);

    // 3. DELETE /urunler/:id — Soft delete
    $router->delete('/urunler/:id', function (array $req) {
        if (!checkUrunYetki($req, 'sil')) return;

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            // Aktif sayimda kullaniliyor mu?
            $stmt = $pdo->prepare(
                "SELECT DISTINCT s.ad FROM sayim_kalemleri sk
                 JOIN sayimlar s ON s.id = sk.sayim_id
                 WHERE sk.urun_id = ? AND s.durum = 'devam' FOR UPDATE"
            );
            $stmt->execute([$req['params']['id']]);
            $aktifSayimlar = $stmt->fetchAll();

            if (count($aktifSayimlar) > 0) {
                $pdo->rollBack();
                json_response([
                    'hata' => 'Bu urun aktif sayimlarda kullaniliyor.',
                    'sayimlar' => array_column($aktifSayimlar, 'ad'),
                ], 409);
            }

            $stmt = $pdo->prepare('UPDATE isletme_urunler SET aktif = 0 WHERE id = ?');
            $stmt->execute([$req['params']['id']]);

            $pdo->commit();
            json_response(['mesaj' => 'Urun silindi.']);
        } catch (\PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            error_log('[DELETE /urunler/:id] ' . $e->getMessage());
            json_error('Sunucu hatasi.', 500);
        }
    }, [auth_guard()]);

    // 4. PUT /urunler/:id/restore — Silinen urunu geri al (admin only)
    $router->put('/urunler/:id/restore', function (array $req) {
        $pdo = get_db();
        try {
            $stmt = $pdo->prepare('SELECT id, aktif FROM isletme_urunler WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            $row = $stmt->fetch();

            if (!$row) json_error('Urun bulunamadi.', 404);
            if ((int)$row['aktif'] === 1) json_error('Bu urun zaten aktif.', 400);

            $stmt = $pdo->prepare('UPDATE isletme_urunler SET aktif = 1, son_guncelleme = NOW() WHERE id = ?');
            $stmt->execute([$req['params']['id']]);

            json_response(['mesaj' => 'Urun geri alindi.']);
        } catch (\PDOException $e) {
            error_log('[PUT /urunler/:id/restore] ' . $e->getMessage());
            json_error('Sunucu hatasi.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // 5. GET /urunler/barkod/:barkod — Kullanici versiyonu
    //    Admin ise admin rotasina dusecek (alttaki rota), bu handler sadece non-admin icin
    $router->get('/urunler/barkod/:barkod', function (array $req) {
        // Admin ise bu handler'i atla, admin versiyonuna birak
        if ($req['user']['rol'] === 'admin') {
            // Return nothing — router will continue to next matching route
            // But since our router stops at first match, we handle admin here too.
            // So we implement both in one handler.
            $isletmeId = $req['query']['isletme_id'] ?? null;
            if (!$isletmeId) json_error('isletme_id zorunludur.', 400);

            $pdo = get_db();
            $stmt = $pdo->prepare(
                'SELECT * FROM isletme_urunler WHERE isletme_id = ? AND aktif = 1 AND barkodlar LIKE ?'
            );
            $stmt->execute([$isletmeId, '%' . $req['params']['barkod'] . '%']);
            $data = $stmt->fetchAll();

            $urun = null;
            foreach ($data as $u) {
                $barkodlar = array_map('trim', explode(',', $u['barkodlar'] ?? ''));
                if (in_array($req['params']['barkod'], $barkodlar, true)) {
                    $urun = $u;
                    break;
                }
            }

            if (!$urun) json_error('Barkod sistemde bulunamadi.', 404);
            json_response($urun);
            return;
        }

        // Non-admin: yetki kontrolu yap
        $isletmeId = $req['query']['isletme_id'] ?? null;
        if (!$isletmeId) json_error('isletme_id zorunludur.', 400);

        $pdo = get_db();
        $stmt = $pdo->prepare(
            'SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1'
        );
        $stmt->execute([$req['user']['id'], $isletmeId]);
        $kiRow = $stmt->fetch();

        if (!$kiRow) json_error('Bu isletmeye erisim yetkiniz yok.', 403);

        $yetkiler = json_decode($kiRow['yetkiler'], true);
        if (!($yetkiler['urun']['goruntule'] ?? false)) {
            json_error('Urun goruntuleme yetkiniz yok.', 403);
        }

        $stmt = $pdo->prepare(
            'SELECT * FROM isletme_urunler WHERE isletme_id = ? AND aktif = 1 AND barkodlar LIKE ?'
        );
        $stmt->execute([$isletmeId, '%' . $req['params']['barkod'] . '%']);
        $data = $stmt->fetchAll();

        $urun = null;
        foreach ($data as $u) {
            $barkodlar = array_map('trim', explode(',', $u['barkodlar'] ?? ''));
            if (in_array($req['params']['barkod'], $barkodlar, true)) {
                $urun = $u;
                break;
            }
        }

        if (!$urun) json_error('Barkod sistemde bulunamadi.', 404);
        json_response($urun);
    }, [auth_guard()]);

    // 6. GET /urunler — Kullanici versiyonu + Admin versiyonu (combined)
    //    Sablon rotasi onceden tanimlanmali
    //    Ama sablon admin-only, oncelik onemli. Sablon'u once tanimlayalim.

    // 7. GET /urunler/sablon — Excel sablon indir (admin only)
    $router->get('/urunler/sablon', function (array $req) {
        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Urunler');

        // Aciklama satiri
        $sheet->setCellValue('A1', 'Isletme, yukleme ekranindaki dropdown\'dan secilir. Bu dosyaya isletme yazmak gerekmez.');
        $sheet->mergeCells('A1:E1');

        // Bos satir (row 2)

        // Header (row 3)
        $sheet->setCellValue('A3', 'urun_kodu');
        $sheet->setCellValue('B3', 'urun_adi');
        $sheet->setCellValue('C3', 'isim_2');
        $sheet->setCellValue('D3', 'birim');
        $sheet->setCellValue('E3', 'barkodlar');

        // Ornek veriler (row 4)
        $sheet->setCellValue('A4', 'SHK001');
        $sheet->setCellValue('B4', 'SEKER 1KG');
        $sheet->setCellValue('C4', 'Sugar 1KG');
        $sheet->setCellValue('D4', 'KG');
        $sheet->setCellValue('E4', '8690814000015');

        // Ornek veriler (row 5)
        $sheet->setCellValue('A5', 'UN001');
        $sheet->setCellValue('B5', 'UN 50KG');
        $sheet->setCellValue('C5', '');
        $sheet->setCellValue('D5', 'KG');
        $sheet->setCellValue('E5', '8691234567890,8699999999999');

        // Sutun genislikleri
        $sheet->getColumnDimension('A')->setWidth(12);
        $sheet->getColumnDimension('B')->setWidth(30);
        $sheet->getColumnDimension('C')->setWidth(25);
        $sheet->getColumnDimension('D')->setWidth(8);
        $sheet->getColumnDimension('E')->setWidth(35);

        // Stream as download
        header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        header('Content-Disposition: attachment; filename="stoksay_sablon.xlsx"');
        header('Cache-Control: max-age=0');

        $writer = new Xlsx($spreadsheet);
        $writer->save('php://output');
        exit;
    }, [auth_guard(), admin_guard()]);

    // 6 + 8. GET /urunler — Combined user + admin list
    $router->get('/urunler', function (array $req) {
        $user = $req['user'];
        $pdo = get_db();

        // ── Non-admin: basit liste ──
        if ($user['rol'] !== 'admin') {
            $isletmeId = $req['query']['isletme_id'] ?? null;
            $q = $req['query']['q'] ?? null;

            if (!$isletmeId) json_error('isletme_id zorunludur.', 400);

            // Yetki kontrolu
            $stmt = $pdo->prepare(
                'SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1'
            );
            $stmt->execute([$user['id'], $isletmeId]);
            $kiRow = $stmt->fetch();

            if (!$kiRow) json_error('Bu isletmeye erisim yetkiniz yok.', 403);

            $yetkiler = json_decode($kiRow['yetkiler'], true);
            if (!($yetkiler['urun']['goruntule'] ?? false)) {
                json_error('Urun goruntuleme yetkiniz yok.', 403);
            }

            $where = ['isletme_id = ?', 'aktif = 1'];
            $params = [$isletmeId];

            if ($q) {
                $where[] = '(urun_adi LIKE ? OR urun_kodu LIKE ? OR barkodlar LIKE ? OR isim_2 LIKE ?)';
                $like = '%' . $q . '%';
                $params[] = $like;
                $params[] = $like;
                $params[] = $like;
                $params[] = $like;
            }

            $whereClause = implode(' AND ', $where);
            $stmt = $pdo->prepare(
                "SELECT id, urun_kodu, urun_adi, isim_2, birim, kategori, barkodlar
                 FROM isletme_urunler
                 WHERE {$whereClause}
                 ORDER BY urun_adi"
            );
            $stmt->execute($params);
            $data = $stmt->fetchAll();

            json_response($data);
            return;
        }

        // ── Admin: paginated list with JOIN ──
        $isletmeId = $req['query']['isletme_id'] ?? null;
        $q = $req['query']['q'] ?? null;
        $alan = $req['query']['alan'] ?? null;
        $aktif = $req['query']['aktif'] ?? null;

        [$sayfa, $limit, $offset] = parse_pagination($req['query'], 20);

        $where = [];
        $params = [];

        // Aktif/pasif filtresi
        if ($aktif === '0') {
            $where[] = 'u.aktif = 0';
        } elseif ($aktif === 'all') {
            // filtre yok
        } else {
            $where[] = 'u.aktif = 1';
        }

        if ($isletmeId) {
            $where[] = 'u.isletme_id = ?';
            $params[] = $isletmeId;
        }

        if ($q) {
            if ($alan === 'isim_2') {
                $where[] = 'u.isim_2 LIKE ?';
                $params[] = '%' . $q . '%';
            } else {
                $where[] = '(u.urun_adi LIKE ? OR u.urun_kodu LIKE ? OR u.barkodlar LIKE ? OR u.isim_2 LIKE ?)';
                $like = '%' . $q . '%';
                $params[] = $like;
                $params[] = $like;
                $params[] = $like;
                $params[] = $like;
            }
        }

        $whereClause = count($where) > 0 ? 'WHERE ' . implode(' AND ', $where) : '';

        // Count
        $stmt = $pdo->prepare("SELECT COUNT(*) AS toplam FROM isletme_urunler u {$whereClause}");
        $stmt->execute($params);
        $toplam = (int)$stmt->fetch()['toplam'];

        // Data with JOIN
        $stmt = $pdo->prepare(
            "SELECT u.*, i.id AS isletme_id_j, i.ad AS isletme_ad
             FROM isletme_urunler u
             LEFT JOIN isletmeler i ON i.id = u.isletme_id
             {$whereClause}
             ORDER BY u.urun_adi
             LIMIT {$limit} OFFSET {$offset}"
        );
        $stmt->execute($params);
        $data = $stmt->fetchAll();

        // Enrich with isletmeler object
        $enriched = array_map(function ($row) {
            $isletmeIdJ = $row['isletme_id_j'] ?? null;
            $isletmeAd = $row['isletme_ad'] ?? null;
            unset($row['isletme_id_j'], $row['isletme_ad']);
            $row['isletmeler'] = ['id' => $isletmeIdJ, 'ad' => $isletmeAd];
            return $row;
        }, $data);

        json_response([
            'data' => $enriched,
            'toplam' => $toplam,
            'sayfa' => $sayfa,
            'limit' => $limit,
        ]);
    }, [auth_guard()]);

    // ═══════════════════════════════════════════════════════════════
    //  ADMIN ROTALARI (auth + admin)
    // ═══════════════════════════════════════════════════════════════

    // 10. GET /urunler/:id — Admin detay
    $router->get('/urunler/:id', function (array $req) {
        $pdo = get_db();
        $stmt = $pdo->prepare('SELECT * FROM isletme_urunler WHERE id = ?');
        $stmt->execute([$req['params']['id']]);
        $row = $stmt->fetch();

        if (!$row) json_error('Urun bulunamadi.', 404);
        json_response($row);
    }, [auth_guard(), admin_guard()]);

    // 11. POST /urunler/:id/barkod — Barkod ekle
    $router->post('/urunler/:id/barkod', function (array $req) {
        $barkod = $req['body']['barkod'] ?? null;

        if (!$barkod) json_error('barkod zorunludur.', 400);
        if (!preg_match('/^[a-zA-Z0-9\-]{1,50}$/', $barkod)) {
            json_error('Gecerli bir barkod giriniz.', 400);
        }

        $pdo = get_db();
        try {
            $pdo->beginTransaction();

            $stmt = $pdo->prepare('SELECT barkodlar, isletme_id FROM isletme_urunler WHERE id = ? FOR UPDATE');
            $stmt->execute([$req['params']['id']]);
            $mevcutRow = $stmt->fetch();

            if (!$mevcutRow) {
                $pdo->rollBack();
                json_error('Urun bulunamadi.', 404);
            }

            $barkodlar = array_values(array_filter(array_map('trim', explode(',', $mevcutRow['barkodlar'] ?? ''))));

            if (in_array($barkod, $barkodlar, true)) {
                $pdo->rollBack();
                json_error('Bu barkod zaten bu urune tanimli.', 409);
            }

            // Ayni isletmede baska urunde bu barkod var mi?
            $cakisan = barkodBenzersizKontrol($pdo, $mevcutRow['isletme_id'], [$barkod], $req['params']['id']);
            if ($cakisan) {
                $pdo->rollBack();
                json_error("\"{$barkod}\" barkodu \"{$cakisan['urunAdi']}\" urununne zaten tanimli.", 409);
            }

            $barkodlar[] = $barkod;

            $stmt = $pdo->prepare('UPDATE isletme_urunler SET barkodlar = ?, son_guncelleme = NOW() WHERE id = ?');
            $stmt->execute([implode(',', $barkodlar), $req['params']['id']]);

            $pdo->commit();

            $stmt = $pdo->prepare('SELECT * FROM isletme_urunler WHERE id = ?');
            $stmt->execute([$req['params']['id']]);
            json_response($stmt->fetch());
        } catch (\PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            error_log('[POST /urunler/:id/barkod] ' . $e->getMessage());
            json_error('Sunucu hatasi.', 500);
        }
    }, [auth_guard(), admin_guard()]);

    // 12. DELETE /urunler/:id/barkod/:barkod — Barkod sil
    $router->delete('/urunler/:id/barkod/:barkod', function (array $req) {
        $pdo = get_db();

        $stmt = $pdo->prepare('SELECT barkodlar FROM isletme_urunler WHERE id = ?');
        $stmt->execute([$req['params']['id']]);
        $mevcutRow = $stmt->fetch();

        if (!$mevcutRow) json_error('Urun bulunamadi.', 404);

        $barkodlar = array_values(array_filter(
            array_map('trim', explode(',', $mevcutRow['barkodlar'] ?? '')),
            fn($b) => strlen($b) > 0 && $b !== $req['params']['barkod']
        ));

        $stmt = $pdo->prepare('UPDATE isletme_urunler SET barkodlar = ?, son_guncelleme = NOW() WHERE id = ?');
        $stmt->execute([implode(',', $barkodlar), $req['params']['id']]);

        $stmt = $pdo->prepare('SELECT * FROM isletme_urunler WHERE id = ?');
        $stmt->execute([$req['params']['id']]);
        json_response($stmt->fetch());
    }, [auth_guard(), admin_guard()]);

    // 13. POST /urunler/yukle — Excel toplu yukleme
    $router->post('/urunler/yukle', function (array $req) {
        $isletmeId = $req['query']['isletme_id'] ?? null;
        $preview = $req['query']['preview'] ?? null;

        if (!$isletmeId) json_error('isletme_id zorunludur.', 400);

        // Dosya kontrolu
        if (!isset($_FILES['dosya']) || $_FILES['dosya']['error'] !== UPLOAD_ERR_OK) {
            json_error('Excel dosyasi gereklidir.', 400);
        }

        $file = $_FILES['dosya'];

        // MIME type kontrolu
        $izinliMimeler = [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/vnd.ms-excel',
            'application/octet-stream',
        ];
        if (!in_array($file['type'], $izinliMimeler, true)) {
            json_error('Sadece .xlsx veya .xls dosyasi yuklenebilir.', 400);
        }

        // Uzanti kontrolu
        $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        if (!in_array($ext, ['xlsx', 'xls'], true)) {
            json_error('Sadece .xlsx veya .xls dosyasi yuklenebilir.', 400);
        }

        // Boyut kontrolu (10 MB)
        if ($file['size'] > 10 * 1024 * 1024) {
            json_error('Dosya 10 MB sinirini asiyor.', 400);
        }

        // PhpSpreadsheet ile oku
        try {
            $spreadsheet = IOFactory::load($file['tmp_name']);
        } catch (\Exception $e) {
            json_error('Dosya okunamadi: ' . $e->getMessage(), 400);
        }

        $sheet = $spreadsheet->getActiveSheet();
        $highestRow = $sheet->getHighestRow();
        $highestCol = $sheet->getHighestColumn();

        // Header satirini bul (urun_kodu iceren ilk satir)
        $headerRow = null;
        $headers = [];
        for ($r = 1; $r <= min($highestRow, 10); $r++) {
            $val = trim((string)$sheet->getCell("A{$r}")->getValue());
            if (strtolower($val) === 'urun_kodu') {
                $headerRow = $r;
                // Tum headerları oku
                $colIdx = 1;
                while (true) {
                    $cellVal = trim((string)$sheet->getCellByColumnAndRow($colIdx, $r)->getValue());
                    if ($cellVal === '') break;
                    $headers[$colIdx] = strtolower($cellVal);
                    $colIdx++;
                }
                break;
            }
        }

        if ($headerRow === null) {
            // Fallback: ilk veri satiri olarak satirlari json olarak parse et
            // PhpSpreadsheet'in sheet_to_json benzeri islem
            $headerRow = 1;
            $colIdx = 1;
            while (true) {
                $cellVal = trim((string)$sheet->getCellByColumnAndRow($colIdx, 1)->getValue());
                if ($cellVal === '') break;
                $headers[$colIdx] = strtolower($cellVal);
                $colIdx++;
            }
        }

        // Parse rows
        $rows = [];
        for ($r = $headerRow + 1; $r <= $highestRow; $r++) {
            $rowData = [];
            $hasData = false;
            foreach ($headers as $colIdx => $headerName) {
                $val = trim((string)$sheet->getCellByColumnAndRow($colIdx, $r)->getValue());
                $rowData[$headerName] = $val;
                if ($val !== '') $hasData = true;
            }
            if ($hasData) {
                $rows[] = $rowData;
            }
        }

        $pdo = get_db();
        $sonuclar = ['yeni' => [], 'degisecek' => [], 'korunacak' => [], 'hatali' => []];
        $upsertListesi = [];

        foreach ($rows as $row) {
            $urunKodu = $row['urun_kodu'] ?? null;
            if (!$urunKodu) {
                $sonuclar['hatali'][] = ['satir' => $row, 'sebep' => 'Urun kodu eksik'];
                continue;
            }

            $barkodlar = implode(',', array_values(array_filter(
                array_map('trim', explode(',', (string)($row['barkodlar'] ?? '')))
            )));

            $stmt = $pdo->prepare(
                'SELECT id, urun_adi, birim, barkodlar, kullanici_guncelledi, admin_version FROM isletme_urunler WHERE isletme_id = ? AND urun_kodu = ?'
            );
            $stmt->execute([$isletmeId, (string)$urunKodu]);
            $mevcut = $stmt->fetch();

            if (!$mevcut) {
                $sonuclar['yeni'][] = array_merge($row, ['barkodlar' => $barkodlar]);
            } elseif (!empty($mevcut['kullanici_guncelledi'])) {
                $sonuclar['korunacak'][] = array_merge($row, ['barkodlar' => $barkodlar, 'sebep' => 'Kullanici duzenledi']);
            } else {
                $sonuclar['degisecek'][] = array_merge($row, ['barkodlar' => $barkodlar]);
            }

            $upsertListesi[] = [
                'isletme_id' => $isletmeId,
                'urun_kodu' => (string)$urunKodu,
                'urun_adi' => $row['urun_adi'] ?? '',
                'isim_2' => isset($row['isim_2']) ? trim((string)$row['isim_2']) : '',
                'birim' => $row['birim'] ?? 'ADET',
                'barkodlar' => $barkodlar,
                'kategori' => $row['kategori'] ?? null,
                'admin_version' => ($mevcut['admin_version'] ?? 0) + 1,
            ];
        }

        // Preview mode
        if ($preview === 'true') {
            json_response($sonuclar);
            return;
        }

        // Upsert
        foreach ($upsertListesi as $urun) {
            $stmt = $pdo->prepare(
                'SELECT barkodlar, kullanici_guncelledi FROM isletme_urunler WHERE isletme_id = ? AND urun_kodu = ?'
            );
            $stmt->execute([$isletmeId, $urun['urun_kodu']]);
            $mevcut = $stmt->fetch();

            // Barkodlari birlestir
            $eskiBarkodlar = array_values(array_filter(array_map('trim', explode(',', $mevcut['barkodlar'] ?? ''))));
            $yeniBarkodlar = array_values(array_filter(array_map('trim', explode(',', $urun['barkodlar']))));
            $tumBarkodlar = implode(',', array_values(array_unique(array_merge($eskiBarkodlar, $yeniBarkodlar))));

            if ($mevcut) {
                if (empty($mevcut['kullanici_guncelledi'])) {
                    // Tam guncelleme
                    $stmt = $pdo->prepare(
                        "UPDATE isletme_urunler SET
                            urun_adi = ?, isim_2 = ?, birim = ?, kategori = ?,
                            barkodlar = ?, admin_version = ?, son_guncelleme = NOW(), guncelleme_kaynagi = 'admin'
                        WHERE isletme_id = ? AND urun_kodu = ?"
                    );
                    $stmt->execute([
                        $urun['urun_adi'],
                        $urun['isim_2'],
                        $urun['birim'],
                        $urun['kategori'],
                        $tumBarkodlar,
                        $urun['admin_version'],
                        $isletmeId,
                        $urun['urun_kodu'],
                    ]);
                } else {
                    // Sadece barkod + admin_version guncelle (kullanici duzenledi)
                    $stmt = $pdo->prepare(
                        "UPDATE isletme_urunler SET
                            barkodlar = ?, admin_version = ?, son_guncelleme = NOW(), guncelleme_kaynagi = 'admin'
                        WHERE isletme_id = ? AND urun_kodu = ?"
                    );
                    $stmt->execute([
                        $tumBarkodlar,
                        $urun['admin_version'],
                        $isletmeId,
                        $urun['urun_kodu'],
                    ]);
                }
            } else {
                // Yeni kayit
                $id = uuid_v4();
                $stmt = $pdo->prepare(
                    "INSERT INTO isletme_urunler
                        (id, isletme_id, urun_kodu, urun_adi, isim_2, birim, barkodlar, kategori, admin_version)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
                );
                $stmt->execute([
                    $id,
                    $isletmeId,
                    $urun['urun_kodu'],
                    $urun['urun_adi'],
                    $urun['isim_2'],
                    $urun['birim'],
                    $tumBarkodlar,
                    $urun['kategori'],
                    $urun['admin_version'],
                ]);
            }
        }

        json_response([
            'mesaj' => 'Yukleme tamamlandi.',
            'yeni' => count($sonuclar['yeni']),
            'degisecek' => count($sonuclar['degisecek']),
            'korunacak' => count($sonuclar['korunacak']),
            'hatali' => count($sonuclar['hatali']),
        ]);
    }, [auth_guard(), admin_guard()]);
}

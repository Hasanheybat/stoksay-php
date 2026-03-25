<?php
/**
 * Granüler Yetki Kontrolü Middleware
 * Express.js yetkiGuard(kategori, islem, source) eşdeğeri
 */
function yetki_guard(string $kategori, string $islem, string $source = 'query'): Closure {
    return function(array &$request) use ($kategori, $islem, $source): bool {
        $user = $request['user'];

        // Admin tüm yetkilere sahip
        if ($user['rol'] === 'admin') return true;

        // isletme_id'yi belirtilen kaynaktan al
        $isletmeId = null;
        if ($source === 'query') {
            $isletmeId = $request['query']['isletme_id'] ?? null;
        } elseif ($source === 'body') {
            $isletmeId = $request['body']['isletme_id'] ?? null;
        } elseif ($source === 'params') {
            $isletmeId = $request['params']['isletme_id'] ?? null;
        }

        if (!$isletmeId) {
            json_error(__t('general.isletme_id_required'), 400);
            return false;
        }

        $pdo = get_db();
        $stmt = $pdo->prepare(
            'SELECT yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND isletme_id = ? AND aktif = 1'
        );
        $stmt->execute([$user['id'], $isletmeId]);
        $row = $stmt->fetch();

        if (!$row) {
            json_error(__t('depo.no_access'), 403);
            return false;
        }

        $yetkiler = json_decode($row['yetkiler'], true);
        if (!($yetkiler[$kategori][$islem] ?? false)) {
            json_error(__t('general.permission_denied', ['kategori' => ucfirst($kategori), 'islem' => $islem]), 403);
            return false;
        }

        return true;
    };
}

<?php
/**
 * JWT Authentication Middleware
 */
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

function auth_guard(): Closure {
    return function(array &$request): bool {
        $config = require __DIR__ . '/../config/config.php';
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';

        if (!$header || !preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
            json_error('Oturum açılmamış.', 401);
            return false;
        }

        try {
            $payload = JWT::decode($m[1], new Key($config['jwt_secret'], 'HS256'));
        } catch (\Exception $e) {
            json_error('Geçersiz veya süresi dolmuş token.', 401);
            return false;
        }

        // Kullanıcıyı DB'den çek
        $pdo = get_db();
        $stmt = $pdo->prepare('SELECT * FROM kullanicilar WHERE id = ?');
        $stmt->execute([$payload->sub]);
        $user = $stmt->fetch();

        if (!$user) {
            json_error('Kullanıcı bulunamadı.', 401);
            return false;
        }

        if (!(bool)(int)$user['aktif']) {
            json_error('Hesabınız pasif durumdadır.', 403);
            return false;
        }

        // password_hash'i çıkar, boolean/JSON decode
        unset($user['password_hash']);
        $user['aktif'] = (bool)(int)$user['aktif'];
        if (isset($user['ayarlar']) && is_string($user['ayarlar'])) {
            $user['ayarlar'] = json_decode($user['ayarlar'], true);
        }

        $request['user'] = $user;
        return true;
    };
}

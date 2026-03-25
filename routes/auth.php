<?php
/**
 * Auth Routes — /api/auth/*
 */
use Firebase\JWT\JWT;

function register_auth_routes(Router $router): void {
    $config = require __DIR__ . '/../config/config.php';

    // POST /api/auth/login
    $router->post('/auth/login', function($req) use ($config) {
        $body = $req['body'];
        $pass = $body['password'] ?? $body['sifre'] ?? null;
        $email = $body['email'] ?? null;

        if (!$email || !$pass) {
            json_error('Email ve şifre zorunludur.', 400);
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            json_error('Geçerli bir email adresi giriniz.', 400);
        }

        $pdo = get_db();
        $stmt = $pdo->prepare('SELECT * FROM kullanicilar WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user) {
            json_error('Geçersiz email veya şifre.', 401);
        }
        if (!(bool)(int)$user['aktif']) {
            json_error('Hesabınız pasif durumdadır.', 403);
        }
        if (!password_verify($pass, $user['password_hash'])) {
            json_error('Geçersiz email veya şifre.', 401);
        }

        $payload = [
            'sub'   => $user['id'],
            'email' => $user['email'],
            'rol'   => $user['rol'],
            'iat'   => time(),
            'exp'   => time() + $config['jwt_expiry'],
        ];
        $token = JWT::encode($payload, $config['jwt_secret'], 'HS256');

        $userData = remove_password_hash($user);
        $userData['aktif'] = (bool)(int)$userData['aktif'];
        if (isset($userData['ayarlar']) && is_string($userData['ayarlar'])) {
            $userData['ayarlar'] = json_decode($userData['ayarlar'], true);
        }

        json_response(['token' => $token, 'kullanici' => $userData]);
    }, [rate_limit_middleware('auth', $config['rate_limits']['auth']['max'], $config['rate_limits']['auth']['window'])]);

    // GET /api/auth/me
    $router->get('/auth/me', function($req) {
        $user = $req['user'];
        $yetkilerMap = [];

        if ($user['rol'] !== 'admin') {
            $pdo = get_db();
            $stmt = $pdo->prepare('SELECT isletme_id, yetkiler FROM kullanici_isletme WHERE kullanici_id = ? AND aktif = 1');
            $stmt->execute([$user['id']]);
            while ($row = $stmt->fetch()) {
                $yetkilerMap[$row['isletme_id']] = json_decode($row['yetkiler'], true);
            }
        }

        json_response(['kullanici' => $user, 'yetkilerMap' => (object)$yetkilerMap]);
    }, [auth_guard()]);

    // PUT /api/auth/update-email
    $router->put('/auth/update-email', function($req) {
        $email = $req['body']['email'] ?? null;
        if (!$email) json_error('Email zorunludur.', 400);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            json_error('Geçerli bir email adresi giriniz.', 400);
        }

        $pdo = get_db();
        try {
            $stmt = $pdo->prepare('UPDATE kullanicilar SET email = ? WHERE id = ?');
            $stmt->execute([trim($email), $req['user']['id']]);
            json_response(['ok' => true]);
        } catch (PDOException $e) {
            if ($e->errorInfo[1] == 1062) {
                json_error('Bu email zaten kullanılıyor.', 409);
            }
            json_error('Sunucu hatası.', 500);
        }
    }, [auth_guard(), rate_limit_middleware('auth', $config['rate_limits']['auth']['max'], $config['rate_limits']['auth']['window'])]);

    // PUT /api/auth/update-password
    $router->put('/auth/update-password', function($req) {
        $body = $req['body'];
        $eski = $body['eskiSifre'] ?? null;
        $yeni = $body['yeniSifre'] ?? null;

        if (!$eski || !$yeni) json_error('Eski ve yeni şifre zorunludur.', 400);
        if (strlen($yeni) < 8) json_error('Yeni şifre en az 8 karakter olmalıdır.', 400);

        $pdo = get_db();
        $stmt = $pdo->prepare('SELECT password_hash FROM kullanicilar WHERE id = ?');
        $stmt->execute([$req['user']['id']]);
        $row = $stmt->fetch();

        if (!$row) json_error('Kullanıcı bulunamadı.', 404);
        if (!password_verify($eski, $row['password_hash'])) {
            json_error('Mevcut şifre hatalı.', 401);
        }

        $hash = password_hash($yeni, PASSWORD_BCRYPT, ['cost' => 10]);
        $stmt = $pdo->prepare('UPDATE kullanicilar SET password_hash = ? WHERE id = ?');
        $stmt->execute([$hash, $req['user']['id']]);

        json_response(['ok' => true]);
    }, [auth_guard(), rate_limit_middleware('auth', $config['rate_limits']['auth']['max'], $config['rate_limits']['auth']['window'])]);
}

<?php
/**
 * StokSay PHP Backend — Front Controller
 * Tüm /api/* istekleri bu dosyadan geçer.
 */

// Hata yönetimi
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

// Backend kök dizini
$backendDir = dirname(dirname(__DIR__));

// Composer autoload
require_once $backendDir . '/vendor/autoload.php';

// Konfigürasyon ve altyapı
require_once $backendDir . '/config/config.php';
require_once $backendDir . '/config/database.php';
require_once $backendDir . '/lib/helpers.php';
require_once $backendDir . '/lib/i18n.php';
require_once $backendDir . '/lib/router.php';

// Middleware
require_once $backendDir . '/middleware/cors.php';
require_once $backendDir . '/middleware/security_headers.php';
require_once $backendDir . '/middleware/rate_limiter.php';
require_once $backendDir . '/middleware/auth_guard.php';
require_once $backendDir . '/middleware/admin_guard.php';
require_once $backendDir . '/middleware/yetki_guard.php';

// Routes
require_once $backendDir . '/routes/auth.php';
require_once $backendDir . '/routes/isletmeler.php';
require_once $backendDir . '/routes/depolar.php';
require_once $backendDir . '/routes/roller.php';
require_once $backendDir . '/routes/kullanicilar.php';
require_once $backendDir . '/routes/profil.php';
require_once $backendDir . '/routes/stats.php';
require_once $backendDir . '/routes/urunler.php';
require_once $backendDir . '/routes/sayimlar.php';

// ── Konfigürasyon yükle ──
$config = require $backendDir . '/config/config.php';

// ── Güvenlik header'ları ──
set_security_headers();

// ── CORS ──
handle_cors($config);

// ── Rate limiter tablosunu oluştur (ilk çalıştırmada) ──
try {
    init_rate_limit_table(get_db());
} catch (\Exception $e) {
    // Tablo zaten varsa hata vermez
}

// ── Request bilgilerini hazırla ──
$method = $_SERVER['REQUEST_METHOD'];
$uri = $_SERVER['REQUEST_URI'];

// /api/ prefix'ini kaldır
$path = parse_url($uri, PHP_URL_PATH);
$path = preg_replace('#^/api#', '', $path);
$path = rtrim($path, '/') ?: '/';

$request = [
    'body'   => get_json_body(),
    'query'  => get_query_params(),
    'params' => [],
    'user'   => null,
];

// ── Router oluştur ve route'ları kaydet ──
$router = new Router();

// Health check
$router->get('/health', function($req) {
    json_response(['status' => 'ok', 'timestamp' => date('c')]);
});

// ── i18n Routes ──
$router->get('/languages', function($req) {
    $i18n = I18n::getInstance();
    json_response($i18n->getAvailableLanguages());
});

$router->get('/translations', function($req) {
    $i18n = I18n::getInstance();
    json_response($i18n->getAllTranslations());
});

$router->put('/user/language', function($req) {
    $lang = $req['body']['lang'] ?? null;
    $i18n = I18n::getInstance();

    if (!$lang || !in_array($lang, $i18n->getSupportedLangs())) {
        json_error(__t('general.validation_error'), 400);
    }

    $pdo = get_db();
    $userId = $req['user']['id'];

    // Mevcut ayarları al
    $stmt = $pdo->prepare('SELECT ayarlar FROM kullanicilar WHERE id = ?');
    $stmt->execute([$userId]);
    $row = $stmt->fetch();
    $ayarlar = $row && $row['ayarlar'] ? json_decode($row['ayarlar'], true) : [];
    $ayarlar['dil'] = $lang;

    $stmt = $pdo->prepare('UPDATE kullanicilar SET ayarlar = ? WHERE id = ?');
    $stmt->execute([json_encode($ayarlar, JSON_UNESCAPED_UNICODE), $userId]);

    json_response(['ok' => true, 'lang' => $lang]);
}, [auth_guard()]);

// Route'ları kaydet
register_auth_routes($router);
register_isletmeler_routes($router);
register_depolar_routes($router);
register_roller_routes($router);
register_kullanicilar_routes($router);
register_profil_routes($router);
register_stats_routes($router);
register_urunler_routes($router);
register_sayimlar_routes($router);

// ── Dispatch ──
$matched = $router->dispatch($method, $path, $request);

if (!$matched) {
    json_error(__t('general.endpoint_not_found'), 404);
}

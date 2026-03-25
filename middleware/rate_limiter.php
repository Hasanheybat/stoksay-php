<?php
/**
 * DB tabanlı Rate Limiter
 */

function init_rate_limit_table(PDO $pdo): void {
    $pdo->exec("CREATE TABLE IF NOT EXISTS rate_limits (
        id INT AUTO_INCREMENT PRIMARY KEY,
        rate_key VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_key_time (rate_key, created_at)
    )");
}

function check_rate_limit(PDO $pdo, string $category, int $maxRequests, int $windowSeconds): bool {
    $key = $category . ':' . get_client_ip();
    $windowStart = date('Y-m-d H:i:s', time() - $windowSeconds);

    // Sayaç kontrol
    $stmt = $pdo->prepare('SELECT COUNT(*) as cnt FROM rate_limits WHERE rate_key = ? AND created_at > ?');
    $stmt->execute([$key, $windowStart]);
    $count = (int)$stmt->fetch()['cnt'];

    if ($count >= $maxRequests) {
        return false; // Rate limit aşıldı
    }

    // Yeni kayıt ekle
    $stmt = $pdo->prepare('INSERT INTO rate_limits (rate_key) VALUES (?)');
    $stmt->execute([$key]);

    // Eski kayıtları temizle (her 100 istek'te bir)
    if (rand(1, 100) === 1) {
        $pdo->prepare('DELETE FROM rate_limits WHERE created_at < ?')->execute([$windowStart]);
    }

    return true;
}

function rate_limit_middleware(string $category, int $max, int $window): Closure {
    return function(array &$request) use ($category, $max, $window): bool {
        $pdo = get_db();
        if (!check_rate_limit($pdo, $category, $max, $window)) {
            json_response([
                'hata' => __t('general.rate_limit'),
            ], 429);
            return false;
        }
        return true;
    };
}

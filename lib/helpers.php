<?php
/**
 * StokSay — Yardımcı Fonksiyonlar
 */

function uuid_v4(): string {
    $data = random_bytes(16);
    $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
    $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function json_response($data, int $status = 200): void {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function json_error(string $hata, int $status = 400): void {
    json_response(['hata' => $hata], $status);
}

function get_json_body(): array {
    $raw = file_get_contents('php://input');
    if (empty($raw)) return [];
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function get_query_params(): array {
    return $_GET;
}

/**
 * Pagination parametrelerini parse et
 */
function parse_pagination(array $query, int $defaultLimit = 50): array {
    $sayfa = max(1, (int)($query['sayfa'] ?? 1));
    $limit = min(200, max(1, (int)($query['limit'] ?? $defaultLimit)));
    $offset = ($sayfa - 1) * $limit;
    return [$sayfa, $limit, $offset];
}

/**
 * Client IP adresini al (proxy arkasında da)
 */
function get_client_ip(): string {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ips = explode(',', $_SERVER['HTTP_X_FORWARDED_FOR']);
        return trim($ips[0]);
    }
    return $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
}

/**
 * password_hash gizleme: satırdan password_hash alanını çıkar
 */
function remove_password_hash(array $row): array {
    unset($row['password_hash']);
    return $row;
}

<?php
/**
 * StokSay — PDO Veritabanı Bağlantısı
 */

function get_db(): PDO {
    static $pdo = null;
    if ($pdo !== null) return $pdo;

    $config = require __DIR__ . '/config.php';

    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=%s',
        $config['db_host'],
        $config['db_port'],
        $config['db_name'],
        $config['db_charset']
    );

    $pdo = new PDO($dsn, $config['db_user'], $config['db_pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
        (defined('Pdo\Mysql::ATTR_INIT_COMMAND') ? \Pdo\Mysql::ATTR_INIT_COMMAND : PDO::MYSQL_ATTR_INIT_COMMAND) => "SET NAMES 'utf8mb4'",
    ]);

    return $pdo;
}

/**
 * JSON ve boolean alanları decode et.
 * MySQL JSON → string, TINYINT(1) → "0"/"1"
 */
function decode_row(array $row, array $jsonFields = [], array $boolFields = []): array {
    foreach ($jsonFields as $f) {
        if (isset($row[$f]) && is_string($row[$f])) {
            $row[$f] = json_decode($row[$f], true);
        }
    }
    foreach ($boolFields as $f) {
        if (array_key_exists($f, $row)) {
            $row[$f] = (bool)(int)$row[$f];
        }
    }
    return $row;
}

/**
 * Birden fazla satır için decode
 */
function decode_rows(array $rows, array $jsonFields = [], array $boolFields = []): array {
    return array_map(fn($r) => decode_row($r, $jsonFields, $boolFields), $rows);
}

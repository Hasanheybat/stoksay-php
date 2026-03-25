<?php

/**
 * StokSay - Uygulama Yapilandirmasi
 *
 * Bu dosyayi config.php olarak kopyalayin ve degerleri doldurun:
 * cp config.example.php config.php
 */

return [
    // Veritabani
    'db' => [
        'host'     => 'DB_HOST',
        'port'     => 3306,
        'database' => 'DB_NAME',
        'username' => 'DB_USERNAME',
        'password' => 'DB_PASSWORD',
        'charset'  => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
    ],

    // JWT Ayarlari
    'jwt' => [
        'secret'          => 'JWT_SECRET_KEY_BURAYA',
        'algorithm'       => 'HS256',
        'access_ttl'      => 900,       // 15 dakika (saniye)
        'refresh_ttl'     => 604800,    // 7 gun (saniye)
    ],

    // Uygulama
    'app' => [
        'name'        => 'StokSay',
        'env'         => 'development',  // development | production
        'debug'       => true,
        'url'         => 'http://localhost:8080',
        'timezone'    => 'Europe/Istanbul',
    ],

    // CORS
    'cors' => [
        'allowed_origins' => ['http://localhost:3000', 'http://localhost:5173'],
        'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
        'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With'],
        'max_age'         => 86400,
    ],

    // Rate Limiting
    'rate_limit' => [
        'enabled'       => true,
        'max_requests'  => 100,
        'window_seconds' => 60,
        'login_max'     => 5,
        'login_window'  => 300,
    ],

    // Dosya Yukleme
    'upload' => [
        'max_size'       => 10 * 1024 * 1024, // 10 MB
        'allowed_types'  => ['xlsx', 'xls', 'csv'],
        'storage_path'   => __DIR__ . '/../storage/uploads',
    ],
];

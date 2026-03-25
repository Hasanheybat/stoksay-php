<?php
/**
 * PHP Built-in Server Router
 * Kullanım: php -S localhost:8888 -t public server.php
 */
$uri = $_SERVER['REQUEST_URI'];
$path = parse_url($uri, PHP_URL_PATH);

// /api/* → front controller
if (preg_match('#^/api(/|$)#', $path)) {
    require __DIR__ . '/public/api/index.php';
    return true;
}

// Statik dosya varsa PHP built-in server serve etsin
$file = $_SERVER['DOCUMENT_ROOT'] . $path;
if (is_file($file)) {
    return false;
}

// SPA fallback → index.html
$index = $_SERVER['DOCUMENT_ROOT'] . '/index.html';
if (is_file($index)) {
    header('Content-Type: text/html; charset=UTF-8');
    readfile($index);
    return true;
}

http_response_code(404);
echo '404 Not Found';
return true;

<?php
/**
 * StokSay — Basit PHP Router
 * Express.js benzeri route tanımlama: GET/POST/PUT/DELETE + :param desteği
 */

class Router {
    private array $routes = [];

    public function get(string $path, $handler, array $middleware = []): void {
        $this->addRoute('GET', $path, $handler, $middleware);
    }

    public function post(string $path, $handler, array $middleware = []): void {
        $this->addRoute('POST', $path, $handler, $middleware);
    }

    public function put(string $path, $handler, array $middleware = []): void {
        $this->addRoute('PUT', $path, $handler, $middleware);
    }

    public function delete(string $path, $handler, array $middleware = []): void {
        $this->addRoute('DELETE', $path, $handler, $middleware);
    }

    private function addRoute(string $method, string $path, $handler, array $middleware): void {
        // :param → named capture group
        $pattern = preg_replace('#:([a-zA-Z_]+)#', '(?P<$1>[^/]+)', $path);
        $pattern = '#^' . $pattern . '$#';

        $this->routes[] = [
            'method'     => $method,
            'pattern'    => $pattern,
            'handler'    => $handler,
            'middleware'  => $middleware,
        ];
    }

    /**
     * Request'i eşleştir ve çalıştır
     * @return bool true = eşleşti, false = 404
     */
    public function dispatch(string $method, string $path, array &$request): bool {
        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) continue;
            if (!preg_match($route['pattern'], $path, $matches)) continue;

            // Named parametreleri çıkar
            $params = [];
            foreach ($matches as $key => $value) {
                if (is_string($key)) {
                    $params[$key] = urldecode($value);
                }
            }
            $request['params'] = $params;

            // Middleware'leri çalıştır
            foreach ($route['middleware'] as $mw) {
                $result = $mw($request);
                if ($result === false) return true; // Middleware response gönderdi, dur
            }

            // Handler'ı çalıştır
            ($route['handler'])($request);
            return true;
        }

        return false;
    }
}

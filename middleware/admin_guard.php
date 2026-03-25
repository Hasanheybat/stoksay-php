<?php
/**
 * Admin Yetkisi Middleware
 */
function admin_guard(): Closure {
    return function(array &$request): bool {
        if (($request['user']['rol'] ?? '') !== 'admin') {
            json_error('Bu işlem için admin yetkisi gereklidir.', 403);
            return false;
        }
        return true;
    };
}

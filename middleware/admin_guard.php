<?php
/**
 * Admin Yetkisi Middleware
 */
function admin_guard(): Closure {
    return function(array &$request): bool {
        if (($request['user']['rol'] ?? '') !== 'admin') {
            json_error(__t('auth.admin_required'), 403);
            return false;
        }
        return true;
    };
}

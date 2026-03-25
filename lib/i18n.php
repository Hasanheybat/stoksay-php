<?php
/**
 * StokSay - Çok Dilli Destek (i18n) Sistemi
 * Desteklenen diller: az (Azerbaycan), ru (Rusça), tr (Türkçe)
 */

class I18n {
    private static $instance = null;
    private $lang = 'tr';
    private $translations = [];
    private $supportedLangs = ['az', 'ru', 'tr'];
    private $langDir;

    private function __construct() {
        $this->langDir = dirname(__DIR__) . '/lang';
    }

    public static function getInstance(): self {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Dili ayarla - Header, query param veya JWT'den
     */
    public function detectLanguage(): void {
        // 1. Query parametresi: ?lang=az
        if (!empty($_GET['lang']) && in_array($_GET['lang'], $this->supportedLangs)) {
            $this->setLang($_GET['lang']);
            return;
        }

        // 2. HTTP Header: Accept-Language veya X-Language
        if (!empty($_SERVER['HTTP_X_LANGUAGE']) && in_array($_SERVER['HTTP_X_LANGUAGE'], $this->supportedLangs)) {
            $this->setLang($_SERVER['HTTP_X_LANGUAGE']);
            return;
        }

        // 3. Accept-Language header'dan ilk eşleşen
        if (!empty($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
            $langs = explode(',', $_SERVER['HTTP_ACCEPT_LANGUAGE']);
            foreach ($langs as $l) {
                $code = strtolower(trim(explode(';', $l)[0]));
                $code = substr($code, 0, 2);
                if (in_array($code, $this->supportedLangs)) {
                    $this->setLang($code);
                    return;
                }
            }
        }

        // 4. JWT token içinden (kullanıcı tercihi)
        // Bu auth_guard.php sonrası çağrılmalı
        global $currentUser;
        if (!empty($currentUser['dil']) && in_array($currentUser['dil'], $this->supportedLangs)) {
            $this->setLang($currentUser['dil']);
            return;
        }

        // 5. Varsayılan: Türkçe
        $this->setLang('tr');
    }

    public function setLang(string $lang): void {
        if (in_array($lang, $this->supportedLangs)) {
            $this->lang = $lang;
            $this->loadTranslations();
        }
    }

    public function getLang(): string {
        return $this->lang;
    }

    public function getSupportedLangs(): array {
        return $this->supportedLangs;
    }

    /**
     * Tüm desteklenen dilleri ve isimlerini döndür
     */
    public function getAvailableLanguages(): array {
        $result = [];
        foreach ($this->supportedLangs as $code) {
            $file = $this->langDir . "/{$code}.json";
            if (file_exists($file)) {
                $data = json_decode(file_get_contents($file), true);
                $result[] = [
                    'code' => $code,
                    'name' => $data['lang_name'] ?? $code,
                ];
            }
        }
        return $result;
    }

    private function loadTranslations(): void {
        $file = $this->langDir . "/{$this->lang}.json";
        if (file_exists($file)) {
            $this->translations = json_decode(file_get_contents($file), true) ?? [];
        }
    }

    /**
     * Çeviri getir
     * @param string $key Çeviri anahtarı (örn: "auth.login_success")
     * @param array $params Değişken parametreler (örn: ['count' => 5])
     * @return string Çevrilmiş metin
     */
    public function t(string $key, array $params = []): string {
        $text = $this->translations[$key] ?? $key;

        // Placeholder değiştirme: {count}, {islem} vb.
        foreach ($params as $k => $v) {
            $text = str_replace('{' . $k . '}', $v, $text);
        }

        return $text;
    }

    /**
     * Tüm UI çevirilerini döndür (frontend için)
     */
    public function getAllUITranslations(): array {
        $ui = [];
        foreach ($this->translations as $key => $value) {
            if (strpos($key, 'ui.') === 0 || strpos($key, 'stats.') === 0) {
                $ui[$key] = $value;
            }
        }
        return $ui;
    }

    /**
     * Tüm çevirileri döndür
     */
    public function getAllTranslations(): array {
        return $this->translations;
    }
}

// Global helper function
function __t(string $key, array $params = []): string {
    return I18n::getInstance()->t($key, $params);
}

// Başlangıçta dili algıla
I18n::getInstance()->detectLanguage();

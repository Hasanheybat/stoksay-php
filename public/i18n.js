/**
 * StokSay i18n Runtime Module
 * Provides global window.__t(key) translation function
 * Works with the built React app as a fallback/runtime layer
 */
(function () {
  'use strict';

  const SUPPORTED_LANGS = ['tr', 'az', 'ru'];
  const LS_KEY = 'stoksay-lang';
  const DEFAULT_LANG = 'az';

  // Detect language from localStorage or browser
  function detectLanguage() {
    const stored = localStorage.getItem(LS_KEY);
    if (stored && SUPPORTED_LANGS.includes(stored)) return stored;
    const browserLang = (navigator.language || '').split('-')[0].toLowerCase();
    if (SUPPORTED_LANGS.includes(browserLang)) return browserLang;
    return DEFAULT_LANG;
  }

  let currentLang = detectLanguage();

  // Minimal embedded translations for runtime use
  const translations = {
    tr: {
      'app.systemOnline': 'Sistem Onlayn',
      'nav.logout': '\u00c7\u0131k\u0131\u015f Et',
      'lang.tr': 'T\u00fcrk\u00e7e',
      'lang.az': 'Az\u0259rbaycanca',
      'lang.ru': '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
    },
    az: {
      'app.systemOnline': 'Sistem Onlayn',
      'nav.logout': '\u00c7\u0131x\u0131\u015f',
      'lang.tr': 'T\u00fcrk\u00e7e',
      'lang.az': 'Az\u0259rbaycanca',
      'lang.ru': '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
    },
    ru: {
      'app.systemOnline': '\u0421\u0438\u0441\u0442\u0435\u043c\u0430 \u043e\u043d\u043b\u0430\u0439\u043d',
      'nav.logout': '\u0412\u044b\u0445\u043e\u0434',
      'lang.tr': 'T\u00fcrk\u00e7e',
      'lang.az': 'Az\u0259rbaycanca',
      'lang.ru': '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
    },
  };

  // Global translate function
  window.__t = function (key) {
    const dict = translations[currentLang] || translations[DEFAULT_LANG];
    return dict[key] || translations[DEFAULT_LANG]?.[key] || key;
  };

  // Language getter/setter
  window.__i18n = {
    get lang() { return currentLang; },
    set lang(newLang) {
      if (!SUPPORTED_LANGS.includes(newLang)) return;
      currentLang = newLang;
      localStorage.setItem(LS_KEY, newLang);
      document.documentElement.lang = newLang;
      window.dispatchEvent(new CustomEvent('languageChanged', { detail: { lang: newLang } }));
    },
    supportedLangs: SUPPORTED_LANGS,
    detectLanguage: detectLanguage,
  };

  // Set html lang
  document.documentElement.lang = currentLang;
})();

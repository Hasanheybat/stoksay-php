/**
 * StokSay Language Switcher
 * Injects a language selector into the admin panel header
 * Works as a standalone runtime enhancement for the built React app
 */
(function () {
  'use strict';

  if (!window.__i18n) return;

  const LANG_FLAGS = { tr: 'TR', az: 'AZ', ru: 'RU' };
  const LANG_NAMES = { tr: 'T\u00fcrk\u00e7e', az: 'Az\u0259rbaycanca', ru: '\u0420\u0443\u0441\u0441\u043a\u0438\u0439' };

  function injectSwitcher() {
    // Look for the header
    const header = document.querySelector('header');
    if (!header) {
      // Retry after React mounts
      setTimeout(injectSwitcher, 500);
      return;
    }

    // Check if already injected
    if (document.getElementById('stoksay-lang-switcher')) return;

    const container = document.createElement('div');
    container.id = 'stoksay-lang-switcher';
    container.style.cssText = 'position:relative;display:inline-flex;align-items:center;';

    const btn = document.createElement('button');
    btn.style.cssText = 'display:flex;align-items:center;gap:6px;padding:6px 10px;border-radius:12px;border:1px solid #E5E7EB;background:#fff;cursor:pointer;font-size:12px;font-weight:700;color:#374151;transition:background .15s;font-family:inherit;';
    btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#6B7280" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg><span>${LANG_FLAGS[window.__i18n.lang]}</span>`;

    btn.addEventListener('mouseenter', () => { btn.style.background = '#F9FAFB'; });
    btn.addEventListener('mouseleave', () => { btn.style.background = '#fff'; });

    const dropdown = document.createElement('div');
    dropdown.style.cssText = 'display:none;position:absolute;right:0;top:100%;margin-top:4px;background:#fff;border:1px solid #E5E7EB;border-radius:12px;box-shadow:0 10px 15px -3px rgba(0,0,0,0.1);z-index:9999;padding:4px 0;min-width:140px;';

    window.__i18n.supportedLangs.forEach((l) => {
      const item = document.createElement('button');
      const isActive = l === window.__i18n.lang;
      item.style.cssText = `display:flex;align-items:center;gap:8px;width:100%;text-align:left;padding:8px 12px;font-size:13px;border:none;cursor:pointer;background:${isActive ? '#EEF2FF' : '#fff'};color:${isActive ? '#4F46E5' : '#374151'};font-weight:${isActive ? '700' : '500'};font-family:inherit;transition:background .15s;`;
      item.innerHTML = `<span style="font-weight:700;font-size:11px;width:24px;">${LANG_FLAGS[l]}</span><span>${LANG_NAMES[l]}</span>`;

      item.addEventListener('mouseenter', () => { if (l !== window.__i18n.lang) item.style.background = '#F9FAFB'; });
      item.addEventListener('mouseleave', () => { item.style.background = l === window.__i18n.lang ? '#EEF2FF' : '#fff'; });

      item.addEventListener('click', () => {
        window.__i18n.lang = l;
        dropdown.style.display = 'none';
        // Reload to let React re-render with new language
        window.location.reload();
      });

      dropdown.appendChild(item);
    });

    let isOpen = false;
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      isOpen = !isOpen;
      dropdown.style.display = isOpen ? 'block' : 'none';
    });

    document.addEventListener('click', () => {
      isOpen = false;
      dropdown.style.display = 'none';
    });

    container.appendChild(btn);
    container.appendChild(dropdown);

    // Insert before the user info section in the header (before the flex-1 spacer ends)
    const spacer = header.querySelector('.flex-1');
    if (spacer && spacer.nextElementSibling) {
      header.insertBefore(container, spacer.nextElementSibling);
    } else {
      header.appendChild(container);
    }
  }

  // Wait for DOM and React to mount
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => setTimeout(injectSwitcher, 300));
  } else {
    setTimeout(injectSwitcher, 300);
  }
})();

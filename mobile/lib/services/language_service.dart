import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/translations.dart';
import 'api_service.dart';

/// Manages translations: loads from API, falls back to embedded translations.
class LanguageService {
  static const _languageKey = 'selected_language';

  static String _currentLanguage = AppTranslations.defaultLanguage;
  static Map<String, String> _translations = {};
  static bool _initialized = false;

  /// Current language code (tr, az, ru)
  static String get currentLanguage => _currentLanguage;

  /// Initialize with saved language preference
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? AppTranslations.defaultLanguage;
    // Load embedded translations as initial state
    _translations = Map<String, String>.from(
      AppTranslations.all[_currentLanguage] ?? AppTranslations.all[AppTranslations.defaultLanguage]!,
    );
    _initialized = true;
  }

  /// Load translations from API for the current language.
  /// Falls back to embedded translations on failure.
  static Future<void> loadFromApi() async {
    try {
      final response = await ApiService.dio.get(
        '/translations',
        options: _langOptions(),
      );
      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final apiTranslations = <String, String>{};
        data.forEach((key, value) {
          apiTranslations[key] = value.toString();
        });
        if (apiTranslations.isNotEmpty) {
          // Merge: API translations override embedded ones
          final embedded = Map<String, String>.from(
            AppTranslations.all[_currentLanguage] ?? AppTranslations.all[AppTranslations.defaultLanguage]!,
          );
          embedded.addAll(apiTranslations);
          _translations = embedded;
        }
      }
    } catch (_) {
      // API failed — keep embedded translations
      _loadEmbedded();
    }
  }

  /// Change language, save preference, and reload translations
  static Future<void> setLanguage(String langCode) async {
    if (!AppTranslations.all.containsKey(langCode)) return;
    _currentLanguage = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, langCode);
    // Load embedded translations immediately
    _loadEmbedded();
    // Try to save preference on backend
    try {
      await ApiService.dio.put(
        '/user/language',
        data: {'language': langCode},
        options: _langOptions(),
      );
    } catch (_) {
      // Ignore — preference is saved locally
    }
    // Try to load API translations
    await loadFromApi();
  }

  /// Translate a key. Returns the key itself if not found.
  static String t(String key) {
    if (!_initialized) {
      // Fallback before init
      final fallback = AppTranslations.all[AppTranslations.defaultLanguage];
      return fallback?[key] ?? key;
    }
    return _translations[key] ?? key;
  }

  /// Load embedded translations for the current language
  static void _loadEmbedded() {
    _translations = Map<String, String>.from(
      AppTranslations.all[_currentLanguage] ?? AppTranslations.all[AppTranslations.defaultLanguage]!,
    );
  }

  static dynamic _langOptions() {
    return null; // Header is added by the interceptor in ApiService
  }

  /// Get all available languages
  static Map<String, String> get availableLanguages => AppTranslations.languageNames;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/language_service.dart';

class LanguageState {
  final String currentLanguage;
  final bool loading;

  LanguageState({
    this.currentLanguage = 'tr',
    this.loading = false,
  });

  LanguageState copyWith({String? currentLanguage, bool? loading}) {
    return LanguageState(
      currentLanguage: currentLanguage ?? this.currentLanguage,
      loading: loading ?? this.loading,
    );
  }
}

class LanguageNotifier extends Notifier<LanguageState> {
  @override
  LanguageState build() {
    return LanguageState(currentLanguage: LanguageService.currentLanguage);
  }

  /// Load translations from API (called after login/init)
  Future<void> loadTranslations() async {
    state = state.copyWith(loading: true);
    await LanguageService.loadFromApi();
    state = state.copyWith(
      currentLanguage: LanguageService.currentLanguage,
      loading: false,
    );
  }

  /// Change language
  Future<void> changeLanguage(String langCode) async {
    state = state.copyWith(loading: true);
    await LanguageService.setLanguage(langCode);
    state = state.copyWith(
      currentLanguage: langCode,
      loading: false,
    );
  }

  /// Translate a key — convenience method
  String t(String key) => LanguageService.t(key);
}

final languageProvider = NotifierProvider<LanguageNotifier, LanguageState>(LanguageNotifier.new);

/// Global translation function — can be called from anywhere
String t(String key) => LanguageService.t(key);

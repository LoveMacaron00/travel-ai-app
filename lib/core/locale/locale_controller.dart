import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const _preferenceKey = 'app_language';
  static const supportedLanguageCodes = {'en', 'th'};

  Locale _locale = const Locale('th');

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage = preferences.getString(_preferenceKey);
    if (savedLanguage != null &&
        supportedLanguageCodes.contains(savedLanguage)) {
      _locale = Locale(savedLanguage);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguageCodes.contains(languageCode) ||
        languageCode == _locale.languageCode) {
      return;
    }

    _locale = Locale(languageCode);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, languageCode);
  }
}

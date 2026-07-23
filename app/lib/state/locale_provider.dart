import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's chosen app language. Null means "follow the system locale"
/// (falling back to English if the system locale isn't one we support).
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'redl_locale';
  static const supportedLocales = [Locale('en'), Locale('fr')];

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}

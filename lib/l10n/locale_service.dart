import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const _key = 'app_locale';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    _locale = Locale(code == 'ar' ? 'ar' : 'en');
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLocale(isArabic ? const Locale('en') : const Locale('ar'));
  }

  String t(String key, {Map<String, String>? args}) {
    final table = translations[_locale.languageCode] ?? translations['en']!;
    var value = table[key] ?? translations['en']![key] ?? key;
    args?.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement);
    });
    return value;
  }
}

extension L10nX on BuildContext {
  String t(String key, {Map<String, String>? args}) =>
      LocaleService.instance.t(key, args: args);
  bool get isArabic => LocaleService.instance.isArabic;
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Intl;
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
    Intl.defaultLocale = _locale.languageCode;
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    // Dates (DateFormat) follow the app language. All app date formats are
    // for display only; API and stored dates are built without DateFormat.
    Intl.defaultLocale = locale.languageCode;
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

/// Translates [key] into the current language. Unlike `context.t`, it needs
/// no BuildContext, so services and helpers can use it too. Screens rebuild
/// on a language switch (see main.dart), so the text stays current.
String tr(String key, {Map<String, String>? args}) =>
    LocaleService.instance.t(key, args: args);

/// A price in Egyptian pounds: "EGP 4500" in English, "4500 ج.م" in Arabic.
String egp(Object? amount) => tr(
  'egpAmount',
  args: {
    'amount': amount is num ? amount.toStringAsFixed(0) : '${amount ?? 0}',
  },
);

/// Fuel types are stored in English ("Petrol"); show them translated.
String fuelLabel(String value) => switch (value.toLowerCase()) {
  'petrol' || 'gasoline' => tr('fuelPetrol'),
  'diesel' => tr('fuelDiesel'),
  'electric' => tr('fuelElectric'),
  'hybrid' => tr('fuelHybrid'),
  _ => value,
};

/// Reasons stored on complimentary rentals ('gift', 'vip', ...).
String giftReasonLabel(String reason) => switch (reason) {
  'gift' => tr('giftReasonGift'),
  'complimentary' => tr('giftReasonComplimentary'),
  'courtesy' => tr('giftReasonCourtesy'),
  'vip' => tr('giftReasonVip'),
  _ => reason,
};

/// Booking and trip statuses as stored ('in_progress', ...), translated.
String statusLabel(String status) {
  final key = 'status_$status';
  final text = tr(key);
  return text == key ? status.replaceAll('_', ' ') : text;
}

/// "1 car" / "5 cars" (Arabic: "سيارة واحدة" / "5 سيارات").
String carCount(int n) =>
    n == 1 ? tr('carCountOne') : tr('carCountMany', args: {'n': '$n'});

/// Addresses are stored as typed or geocoded; only the default
/// "Cairo, Egypt" is ours, so translate that one for display.
String addressLabel(String address) =>
    address == 'Cairo, Egypt' ? tr('cairoEgypt') : address;

/// Payment methods as stored on bookings and payments ('cash', 'paymob', ...).
String paymentMethodLabel(String method) => switch (method.toLowerCase()) {
  'cash' => tr('cashPickup'),
  'instapay' => tr('instapay'),
  'wallet' => tr('walletTransfer'),
  'paymob' || 'card' => tr('card'),
  _ => method,
};

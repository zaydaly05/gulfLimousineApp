import 'locale_service.dart';

/// Display helpers for content people type in English (car names, colours,
/// wallet brands). What is saved does not change.

const _colours = <String, String>{
  'black': 'أسود',
  'white': 'أبيض',
  'silver': 'فضي',
  'grey': 'رمادي',
  'gray': 'رمادي',
  'dark grey': 'رمادي داكن',
  'dark gray': 'رمادي داكن',
  'blue': 'أزرق',
  'dark blue': 'أزرق داكن',
  'navy': 'كحلي',
  'navy blue': 'كحلي',
  'red': 'أحمر',
  'burgundy': 'نبيتي',
  'maroon': 'نبيتي',
  'green': 'أخضر',
  'dark green': 'أخضر داكن',
  'yellow': 'أصفر',
  'orange': 'برتقالي',
  'gold': 'ذهبي',
  'golden': 'ذهبي',
  'beige': 'بيج',
  'brown': 'بني',
  'champagne': 'شامبين',
  'bronze': 'برونزي',
  'pearl white': 'أبيض لؤلؤي',
  'purple': 'بنفسجي',
  'pink': 'وردي',
};

/// A colour name in the app's language: common colours are translated, any
/// other name is shown as the admin typed it.
String colourLabel(String name) {
  if (!LocaleService.instance.isArabic) return name;
  return _colours[name.trim().toLowerCase()] ?? name;
}

/// A car's name in the app's language: its optional Arabic name (`name_ar`,
/// set by the admin) in Arabic mode, otherwise its name. Works for car
/// documents (`name`) and bookings (`car_name`, `carName`, `car_name_ar`).
String carNameOf(Map<String, dynamic> data, {String fallback = ''}) {
  if (LocaleService.instance.isArabic) {
    final ar = (data['name_ar'] ?? data['car_name_ar'] ?? '').toString().trim();
    if (ar.isNotEmpty) return ar;
  }
  final name = (data['name'] ?? data['carName'] ?? data['car_name'] ?? '')
      .toString()
      .trim();
  return name.isEmpty ? fallback : name;
}

/// Egyptian mobile-wallet brands, in the app's language.
String walletBrandLabel(String brand) {
  if (!LocaleService.instance.isArabic) return brand;
  return switch (brand) {
    'Vodafone Cash' => 'فودافون كاش',
    'Orange Cash' => 'أورنج كاش',
    'Etisalat Cash' => 'اتصالات كاش',
    'e& Cash' => 'إي آند كاش',
    'WE Pay' => 'وي باي',
    _ => brand,
  };
}

/// Traffic violation types an admin picks from; stored as `violationType`.
const violationTypes = [
  'speeding',
  'red_light',
  'parking',
  'no_seatbelt',
  'phone_while_driving',
  'wrong_way',
  'other',
];

String violationTypeLabel(String type) => switch (type) {
  'speeding' => tr('vSpeeding'),
  'red_light' => tr('vRedLight'),
  'parking' => tr('vParking'),
  'no_seatbelt' => tr('vNoSeatbelt'),
  'phone_while_driving' => tr('vPhone'),
  'wrong_way' => tr('vWrongWay'),
  'other' => tr('vOther'),
  _ => type,
};

/// "Speeding · Ring Road, 120 km/h" from the type and the admin's note.
/// Older tickets have only the typed note.
String violationText(Map<String, dynamic> data) {
  final type = (data['violationType'] ?? '').toString();
  final note = (data['description'] ?? '').toString().trim();
  if (type.isEmpty) return note;
  final label = violationTypeLabel(type);
  return note.isEmpty ? label : '$label · $note';
}

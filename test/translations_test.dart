import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/l10n/translations.dart';

void main() {
  // A missing key doesn't crash: LocaleService.t() shows the key itself,
  // so a typo like t('return') silently puts "return" on screen.
  test('every t() key used in lib/ exists in English and Arabic', () {
    final call = RegExp(r"""\.t\('([A-Za-z0-9_]+)'""");
    final missing = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final m in call.allMatches(file.readAsStringSync())) {
        final key = m.group(1)!;
        for (final lang in ['en', 'ar']) {
          if (!translations[lang]!.containsKey(key)) {
            missing.add('${file.path}: $key ($lang)');
          }
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('English and Arabic have the same keys', () {
    final en = translations['en']!.keys.toSet();
    final ar = translations['ar']!.keys.toSet();
    expect(en.difference(ar), isEmpty, reason: 'missing in Arabic');
    expect(ar.difference(en), isEmpty, reason: 'missing in English');
  });

  // Notifications store keys the reader's app translates
  // (lib/l10n/notification_text.dart), written by the app and the server.
  test('every notification key exists in English and Arabic', () {
    final key = RegExp(r"""['"](n[A-Z][A-Za-z]+)['"]""");
    final missing = <String>{};
    final files =
        [
          ...Directory('lib').listSync(recursive: true),
          ...Directory('payments_server/api').listSync(),
        ].whereType<File>().where(
          (f) => f.path.endsWith('.dart') || f.path.endsWith('.js'),
        );
    var found = 0;
    for (final file in files) {
      if (file.path.contains('l10n/translations.dart')) continue;
      for (final m in key.allMatches(file.readAsStringSync())) {
        found++;
        for (final lang in ['en', 'ar']) {
          if (!translations[lang]!.containsKey(m.group(1))) {
            missing.add('${file.path}: ${m.group(1)} ($lang)');
          }
        }
      }
    }
    expect(found, greaterThan(20));
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}

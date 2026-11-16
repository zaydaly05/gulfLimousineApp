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
}

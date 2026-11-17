import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/l10n/server_errors.dart';
import 'package:gulflimousine_travel/l10n/translations.dart';

/// Every message payments_server can send must have an Arabic translation.
void main() {
  // Literal messages in the server: `error: '...'`, `Refusal(code, '...')`,
  // `return '...'` in lib/booking.js, and the two-way "free cars" message.
  final literal = RegExp(
    r"""(?:error:\s*|Refusal\(\d+,\s*|return\s+|\?\s*|:\s*)'([A-Z][^'\n]*)'""",
  );
  final template = RegExp(r'(?:error:\s*|:\s*)`([A-Z][^`\n]*)`');

  List<String> serverMessages() {
    final out = <String>{};
    for (final dir in ['../payments_server/api', '../payments_server/lib']) {
      final d = Directory(dir).existsSync()
          ? Directory(dir)
          : Directory(dir.substring(3));
      for (final f in d.listSync().whereType<File>()) {
        // health.js is for the developer; return.js is a web page.
        if (!f.path.endsWith('.js') ||
            f.path.endsWith('health.js') ||
            f.path.endsWith('return.js')) {
          continue;
        }
        final src = f.readAsStringSync();
        for (final m in literal.allMatches(src)) {
          out.add(m.group(1)!);
        }
        for (final m in template.allMatches(src)) {
          // Fill ${...} with a sample number so the pattern can be checked.
          out.add(
            m
                .group(1)!
                .replaceAllMapped(
                  RegExp(r"\$\{[^}]*=== 1 \? '([^']*)'[^}]*\}"),
                  (x) => x.group(1)!,
                )
                .replaceAll(RegExp(r'\$\{[^}]*\}'), '3'),
          );
        }
      }
    }
    return out.toList();
  }

  test('every server error message has a translation', () {
    final messages = serverMessages().where(
      // Not errors: content of Paymob and notification texts.
      (m) => m.endsWith('.') || !m.contains(' ') || m.length < 90,
    );
    final missing = <String>[];
    for (final m in messages) {
      final key = serverMessageKey(m);
      if (key == null) {
        if (_looksLikeError(m)) missing.add(m);
        continue;
      }
      for (final lang in ['en', 'ar']) {
        if (!translations[lang]!.containsKey(key)) {
          missing.add('$m -> $key ($lang)');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('numbers in server messages carry over', () {
    expect(
      localizeServerMessage('Only 2 cars are free on those dates.'),
      contains('2'),
    );
    expect(
      localizeServerMessage('Return km must be at least 1200.'),
      contains('1200'),
    );
    expect(localizeServerMessage('Something new'), 'Something new');
  });
}

/// Notification titles, translated through the notification keys instead.
const _notificationTitles = {
  'Booking confirmed',
  'Booking received',
  'Return km recorded',
};

bool _looksLikeError(String m) =>
    !_notificationTitles.contains(m) &&
    RegExp(
      r'^(Please|Choose|Could not|Enter|Invalid|Not |This |The |These |Only |No |'
      r'Add |Paymob|Online|Car not|Booking|Bookings|Record|Return|That|Ticket|You |Use POST)',
    ).hasMatch(m);

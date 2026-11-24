import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/services/link_launcher.dart';

void main() {
  group('LinkLauncher.whatsAppNumber', () {
    test('adds the Egypt country code to local mobile numbers', () {
      expect(LinkLauncher.whatsAppNumber('01012345678'), '201012345678');
      expect(LinkLauncher.whatsAppNumber('010 1234 5678'), '201012345678');
    });

    test('drops + and 00 from international numbers', () {
      expect(LinkLauncher.whatsAppNumber('+201001116666'), '201001116666');
      expect(LinkLauncher.whatsAppNumber('00201001116666'), '201001116666');
      expect(LinkLauncher.whatsAppNumber('+971 50 123 4567'), '971501234567');
    });

    test('is empty when there are no digits', () {
      expect(LinkLauncher.whatsAppNumber(''), '');
      expect(LinkLauncher.whatsAppNumber('n/a'), '');
    });
  });

  test('whatsAppUri builds a wa.me link with the message encoded', () {
    final uri = LinkLauncher.whatsAppUri('01012345678', 'Hi & bye');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/201012345678');
    expect(uri.queryParameters['text'], 'Hi & bye');
  });
}

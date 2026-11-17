import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/l10n/locale_service.dart';
import 'package:gulflimousine_travel/l10n/notification_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final booking = {
    'title': 'Booking confirmed',
    'body': 'Your 1 × BMW rental is confirmed. Open My Bookings for details.',
    'i18n': notificationI18n('nBookingConfirmed', 'nBookingBody', {
      'units': '1 × BMW',
      'bookingStatus': 'confirmed',
    }),
  };

  test('shows the reader their own language, statuses included', () async {
    await LocaleService.instance.setLocale(const Locale('ar'));
    final (title, body) = notificationText(booking);
    expect(title, 'تم تأكيد الحجز');
    expect(body, contains('1 × BMW'));
    expect(body, contains('مؤكدة'));
    await LocaleService.instance.setLocale(const Locale('en'));
    expect(notificationText(booking).$2, contains('is Confirmed'));
  });

  test('older notifications without keys keep their text', () {
    expect(notificationText({'title': 'Hi', 'body': 'There'}), ('Hi', 'There'));
    expect(
      notificationText({
        'title': 'Hi',
        'body': 'There',
        'i18n': {'title': 'nNoSuchKey'},
      }),
      ('Hi', 'There'),
    );
  });
}

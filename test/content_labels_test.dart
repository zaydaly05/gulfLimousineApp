import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/l10n/content_labels.dart';
import 'package:gulflimousine_travel/l10n/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  tearDown(() => LocaleService.instance.setLocale(const Locale('en')));

  test('English shows content as typed', () {
    expect(colourLabel('Black'), 'Black');
    expect(carNameOf({'name': 'BMW 7', 'name_ar': 'بي إم دبليو'}), 'BMW 7');
    expect(walletBrandLabel('Vodafone Cash'), 'Vodafone Cash');
  });

  test(
    'Arabic translates common colours and uses the Arabic car name',
    () async {
      await LocaleService.instance.setLocale(const Locale('ar'));
      expect(colourLabel(' black '), 'أسود');
      expect(colourLabel('Midnight Sapphire'), 'Midnight Sapphire');
      expect(
        carNameOf({'name': 'BMW 7', 'name_ar': 'بي إم دبليو'}),
        'بي إم دبليو',
      );
      expect(carNameOf({'car_name': 'BMW 7'}), 'BMW 7');
      expect(carNameOf({}, fallback: 'x'), 'x');
      expect(walletBrandLabel('Vodafone Cash'), 'فودافون كاش');
    },
  );

  test('violation text combines the type and the note', () {
    expect(
      violationText({'violationType': 'speeding', 'description': 'Ring Road'}),
      'Speeding · Ring Road',
    );
    expect(violationText({'description': 'Old ticket'}), 'Old ticket');
  });
}

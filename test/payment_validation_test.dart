import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/utils/payment_validation.dart';

void main() {
  group('normalizeEgyptianMobile', () {
    test('accepts the four operators in common formats', () {
      expect(normalizeEgyptianMobile('01012345678'), '01012345678');
      expect(normalizeEgyptianMobile('011 2345 6789'), '01123456789');
      expect(normalizeEgyptianMobile('+20 122 345 6789'), '01223456789');
      expect(normalizeEgyptianMobile('00201512345678'), '01512345678');
      expect(normalizeEgyptianMobile('201012345678'), '01012345678');
    });

    test('rejects other numbers', () {
      expect(normalizeEgyptianMobile(''), isNull);
      expect(normalizeEgyptianMobile('01312345678'), isNull); // no 013
      expect(normalizeEgyptianMobile('0101234567'), isNull); // too short
      expect(normalizeEgyptianMobile('0223456789'), isNull); // landline
      expect(normalizeEgyptianMobile('abc'), isNull);
    });
  });

  test('isValidPaymentReference', () {
    expect(isValidPaymentReference('123456789012'), isTrue);
    expect(isValidPaymentReference(' TX-9A8B7C '), isTrue);
    expect(isValidPaymentReference('12345'), isFalse);
    expect(isValidPaymentReference('abc def ghi'), isFalse);
    expect(isValidPaymentReference(''), isFalse);
  });
}

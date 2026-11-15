import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/services/complimentary_rental_service.dart';

void main() {
  group('ComplimentaryRentalService.giftedValue', () {
    test('prefers the stored gifted value', () {
      expect(
        ComplimentaryRentalService.giftedValue({
          'gifted_value': 900,
          'total_amount': 500,
        }),
        900,
      );
    });

    test('falls back to total_amount', () {
      expect(
        ComplimentaryRentalService.giftedValue({'total_amount': 500}),
        500,
      );
    });

    test('computes days × daily rate when no amount is stored', () {
      expect(
        ComplimentaryRentalService.giftedValue({
          'days': 3,
          'price_per_day': 250,
        }),
        750,
      );
    });

    test('is zero with no pricing data', () {
      expect(ComplimentaryRentalService.giftedValue({}), 0);
    });
  });
}

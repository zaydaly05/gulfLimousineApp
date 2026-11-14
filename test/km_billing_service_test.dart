import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/services/km_billing_service.dart';

void main() {
  group('KmBillingService', () {
    test('no extra charge within the daily allowance', () {
      final result = KmBillingService.calculate(
        startKm: 1000,
        endKm: 1200,
        rentalDays: 2, // 240 km allowed
      );
      expect(result.drivenKm, 200);
      expect(result.allowedKm, 240);
      expect(result.extraKm, 0);
      expect(result.extraKmChargeEgp, 0);
    });

    test('charges each km over the allowance', () {
      final result = KmBillingService.calculate(
        startKm: 0,
        endKm: 150,
        rentalDays: 1, // 120 km allowed
      );
      expect(result.extraKm, 30);
      expect(result.extraKmChargeEgp, 30 * KmBillingService.extraKmRateEgp);
      expect(
        KmBillingService.finalAmount(baseAmount: 1000, billing: result),
        1000 + 30 * KmBillingService.extraKmRateEgp,
      );
    });

    test('treats zero or negative days as one day', () {
      expect(KmBillingService.allowedKm(0), KmBillingService.kmPerDay);
      expect(KmBillingService.allowedKm(-3), KmBillingService.kmPerDay);
    });

    test('rejects a return reading below the pickup reading', () {
      expect(
        () => KmBillingService.calculate(
          startKm: 500,
          endKm: 400,
          rentalDays: 1,
        ),
        throwsArgumentError,
      );
    });
  });
}

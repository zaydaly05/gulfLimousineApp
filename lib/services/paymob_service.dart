import 'payments_server_client.dart';
import '../l10n/locale_service.dart';

/// A checkout session on Paymob's hosted payment page.
class PaymobCheckout {
  const PaymobCheckout({required this.url, required this.testMode});

  final Uri url;

  /// Sandbox keys: no real money moves, and Paymob's test wallet and cards
  /// work (see payments_server/README.md).
  final bool testMode;
}

/// Starts Paymob checkouts through payments_server, which holds the Paymob
/// secret key. The app never sees that key, and never decides the amount or
/// whether a payment succeeded: the server reads the price from Firestore
/// and only Paymob's signed callback marks a booking paid.
class PaymobService {
  const PaymobService._();

  /// [method] is 'card' or 'wallet' to open Paymob on just that method;
  /// null offers every method the account has.
  static Future<PaymobCheckout> startCheckout(
    String bookingId, {
    String? method,
  }) async {
    final body = await PaymentsServerClient.post('/api/create-intention', {
      'bookingId': bookingId,
      'method': ?method,
    });
    final url = Uri.tryParse(body['checkoutUrl']?.toString() ?? '');
    if (url == null || url.scheme != 'https') {
      throw ServerException(tr('invalidPaymentLink'));
    }
    return PaymobCheckout(url: url, testMode: body['testMode'] == true);
  }
}

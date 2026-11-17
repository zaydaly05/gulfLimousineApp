import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'app_config_service.dart';

/// A checkout session on Paymob's hosted payment page.
class PaymobCheckout {
  const PaymobCheckout({required this.url, required this.testMode});

  final Uri url;

  /// Sandbox keys: no real money moves, and Paymob's test wallet and cards
  /// work (see payments_server/README.md).
  final bool testMode;
}

class PaymobException implements Exception {
  const PaymobException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to payments_server, which holds the Paymob secret key. The app
/// never sees that key, and never decides the amount or whether a payment
/// succeeded: the server reads the price from Firestore and only Paymob's
/// signed callback marks a booking paid.
class PaymobService {
  const PaymobService._();

  static Future<PaymobCheckout> startCheckout(String bookingId) async {
    final config = await AppConfigService.instance.load();
    if (!config.hasPaymob) {
      throw const PaymobException('Online payment is not set up yet.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const PaymobException('Please sign in again.');
    final idToken = await user.getIdToken();

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${config.paymentsServerUrl}/api/create-intention'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'bookingId': bookingId}),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const PaymobException(
        'Could not reach the payment service. Check your connection.',
      );
    }

    final body = _decode(response.body);
    if (response.statusCode != 200) {
      throw PaymobException(
        body['error']?.toString() ?? 'Payment could not be started.',
      );
    }
    final url = Uri.tryParse(body['checkoutUrl']?.toString() ?? '');
    if (url == null || url.scheme != 'https') {
      throw const PaymobException('Payment service sent an invalid link.');
    }
    return PaymobCheckout(url: url, testMode: body['testMode'] == true);
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final json = jsonDecode(body);
      return json is Map<String, dynamic> ? json : const {};
    } catch (_) {
      return const {};
    }
  }
}

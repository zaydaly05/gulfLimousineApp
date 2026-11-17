import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'app_config_service.dart';
import '../l10n/locale_service.dart';
import '../l10n/server_errors.dart';

/// A refusal or failure from payments_server, with a message to show.
class ServerException implements Exception {
  const ServerException(this.message, {this.body = const {}});
  final String message;

  /// The decoded response, for callers that need more than the message.
  final Map<String, dynamic> body;

  @override
  String toString() => message;
}

/// Calls payments_server as the signed-in user (Firebase ID token).
class PaymentsServerClient {
  const PaymentsServerClient._();

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final config = await AppConfigService.instance.load();
    if (!config.hasPaymob) {
      throw ServerException(tr('notAvailableNow'));
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ServerException(tr('pleaseSignInAgain'));
    final idToken = await user.getIdToken();

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${config.paymentsServerUrl}$path'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (_) {
      throw ServerException(tr('couldNotReachServer'));
    }

    final decoded = _decode(response.body);
    if (response.statusCode != 200) {
      throw ServerException(
        decoded['error'] is String
            ? localizeServerMessage(decoded['error'] as String)
            : tr('somethingWentWrong'),
        body: decoded,
      );
    }
    return decoded;
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

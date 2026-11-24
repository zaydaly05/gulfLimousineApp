import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links in other apps (browser, dialer, mail, WhatsApp).
///
/// Calls [launchUrl] directly instead of asking [canLaunchUrl] first:
/// on Android 11+ and iOS, `canLaunchUrl` answers false for any scheme the
/// app hasn't declared (manifest `<queries>` / `LSApplicationQueriesSchemes`),
/// so the buttons silently did nothing. `launchUrl` needs no declaration and
/// reports failure itself.
class LinkLauncher {
  LinkLauncher._();

  /// Opens [uri] outside the app. Returns false (never throws) when no app
  /// can handle it.
  static Future<bool> open(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('Could not open ${uri.scheme} link: $e');
      return false;
    }
  }

  /// A phone number as wa.me expects it: digits only, with the country
  /// code and no leading `+` or `00`. Egyptian local numbers
  /// (`01xxxxxxxxx`) get the +20 country code, which wa.me requires.
  /// Returns an empty string when there are no digits.
  static String whatsAppNumber(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    // Egyptian mobile in local form: 0 + 10 digits starting with 1.
    if (digits.length == 11 && digits.startsWith('01')) {
      digits = '20${digits.substring(1)}';
    }
    return digits;
  }

  /// A wa.me link to [phone] with [message] prefilled.
  static Uri whatsAppUri(String phone, [String? message]) {
    final number = whatsAppNumber(phone);
    return Uri.https('wa.me', '/$number', {
      if (message != null && message.isNotEmpty) 'text': message,
    });
  }
}

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  /// Message a chauffeur
  static Future<void> messageChauffeur({
    required String phone,
    required String carName,
    required String bookingId,
  }) async {
    final text = 'Hello, I am the client for booking #$bookingId ($carName).';
    await _launchWhatsApp(phone, text);
  }

  /// Message a customer (Admin use)
  static Future<void> messageCustomer({
    required String phone,
    required String customerName,
    String? bookingId,
  }) async {
    final text =
        'Hello $customerName, this is Gulf Limousine Travel regarding your booking ${bookingId != null ? '#$bookingId' : ''}.';
    await _launchWhatsApp(phone, text);
  }

  /// Internal helper to launch WhatsApp
  static Future<void> _launchWhatsApp(String phone, String message) async {
    // Remove non-numeric characters from phone
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url =
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch WhatsApp for $url');
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
    }
  }
}

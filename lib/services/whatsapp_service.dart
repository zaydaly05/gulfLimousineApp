import 'package:flutter/foundation.dart';

import 'link_launcher.dart';

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

  /// Opens WhatsApp on [phone] (local Egyptian or international format).
  static Future<void> _launchWhatsApp(String phone, String message) async {
    if (LinkLauncher.whatsAppNumber(phone).isEmpty) return;
    final opened = await LinkLauncher.open(
      LinkLauncher.whatsAppUri(phone, message),
    );
    if (!opened) debugPrint('Could not launch WhatsApp'); // no number in logs
  }
}

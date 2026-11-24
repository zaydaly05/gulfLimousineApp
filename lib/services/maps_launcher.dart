import '../models/geo_location.dart';
import 'link_launcher.dart';

class MapsLauncher {
  static Future<void> openDirections({
    GeoLocation? destination,
    GeoLocation? origin,
  }) async {
    if (destination == null || !destination.isValid) return;

    final dest = '${destination.lat},${destination.lng}';
    final originParam = origin != null && origin.isValid
        ? '&origin=${origin.lat},${origin.lng}'
        : '';

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$dest$originParam',
    );
    await LinkLauncher.open(uri);
  }

  static Future<void> callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    await LinkLauncher.open(Uri.parse('tel:$cleaned'));
  }
}

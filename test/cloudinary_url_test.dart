import 'package:flutter_test/flutter_test.dart';
import 'package:gulflimousine_travel/services/cloudinary_service.dart';

void main() {
  group('CloudinaryService.isOwnAssetUrl', () {
    test('accepts https URLs on the app\'s Cloudinary account', () {
      expect(
        CloudinaryService.isOwnAssetUrl(
          'https://res.cloudinary.com/${CloudinaryService.cloudName}/video/upload/v1/x.mp4',
        ),
        isTrue,
      );
    });

    test('rejects other hosts, other accounts and plain http', () {
      for (final url in [
        'https://evil.example.com/delnnzcph/video.mp4',
        'https://res.cloudinary.com/someone-else/video/upload/x.mp4',
        'http://res.cloudinary.com/${CloudinaryService.cloudName}/video/upload/x.mp4',
        'not a url',
      ]) {
        expect(CloudinaryService.isOwnAssetUrl(url), isFalse, reason: url);
      }
    });
  });
}

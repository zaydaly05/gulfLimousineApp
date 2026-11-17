import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config_service.dart';

class OdometerService {
  /// Reads an odometer photo and returns the km reading, or null if OCR fails.
  static Future<int?> extractKmFromImage(List<int> imageBytes) async {
    final config = await AppConfigService.instance.load();
    if (!config.hasGemini) return null;

    try {
      final base64Image = base64Encode(imageBytes);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${config.geminiModel}:generateContent',
      );

      final body = {
        'contents': [
          {
            'parts': [
              {
                'text':
                    'This image shows a car odometer or dashboard mileage display. '
                    'Extract the total odometer reading in kilometers as a single integer. '
                    'Reply with ONLY the number, no units, no punctuation, no explanation. '
                    'If you cannot read it, reply with NONE.',
              },
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
              },
            ],
          },
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 32},
      };

      final response = await http
          .post(
            uri,
            // Key in a header, not the URL, so it stays out of proxy/server logs.
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': config.geminiApiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final text = parts?.first['text']?.toString().trim();
      if (text == null || text.isEmpty || text.toUpperCase() == 'NONE') {
        return null;
      }

      final digits = RegExp(r'\d+').allMatches(text.replaceAll(',', ''));
      if (digits.isEmpty) return null;

      final value = int.tryParse(digits.last.group(0)!);
      return value != null && value > 0 ? value : null;
    } catch (_) {
      return null;
    }
  }
}

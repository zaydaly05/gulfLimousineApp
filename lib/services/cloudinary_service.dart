import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../l10n/locale_service.dart';

class CloudinaryService {
  static const String cloudName = 'delnnzcph';

  /// Whether [url] points at a file in this app's Cloudinary account.
  /// Booking documents carry URLs written by customers, so viewers check
  /// this before loading anything.
  static bool isOwnAssetUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'res.cloudinary.com' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == cloudName;
  }

  final String uploadPreset = 'flutter_upload';

  /// Picks a gallery image and uploads it. Returns null only when the user
  /// cancels the picker; throws if the upload fails.
  Future<Map<String, dynamic>?> uploadImage() async {
    final picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return uploadBytes(bytes, filename: image.name);
  }

  /// Capture from camera and upload to Cloudinary.
  Future<Map<String, dynamic>?> captureAndUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return uploadBytes(bytes, filename: image.name);
  }

  /// Uploads [bytes] and returns `secure_url` and `public_id`.
  ///
  /// Throws when the upload fails or times out, so callers show an error.
  /// It used to return null, which the pickers' callers read as "the user
  /// cancelled": a failed car-image upload showed nothing, and the profile
  /// screen said "Changes saved" while dropping a new ID photo.
  Future<Map<String, dynamic>?> uploadBytes(
    List<int> bytes, {
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/${_isVideo(filename) ? "video" : "image"}/upload',
      ),
    );

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    // Generous for condition videos on mobile data; never hang forever.
    final response = await request.send().timeout(_uploadTimeout);
    final body = await response.stream.bytesToString().timeout(_uploadTimeout);

    if (response.statusCode != 200) {
      debugPrint('Upload failed: ${response.statusCode}');
      throw Exception(tr('uploadFailed'));
    }
    final json = jsonDecode(body);
    final secureUrl = json is Map ? json['secure_url']?.toString() : null;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception(tr('uploadFailed'));
    }
    return {"secure_url": secureUrl, "public_id": json['public_id']};
  }

  static const _uploadTimeout = Duration(minutes: 3);

  static bool _isVideo(String filename) {
    final name = filename.toLowerCase();
    return name.endsWith('.mp4') || name.endsWith('.mov');
  }

  /// Upload video and return secure_url and public_id
  Future<Map<String, dynamic>?> uploadVideo(File videoFile) async {
    final bytes = await videoFile.readAsBytes();
    return uploadBytes(
      bytes,
      filename: 'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  /// Whether deletes go to the `deleteCloudinaryAsset` Cloud Function.
  ///
  /// Off by default: Cloud Functions need the paid Firebase Blaze plan, so
  /// until the functions are deployed (see functions/README.md) deletes are
  /// skipped and files simply stay in Cloudinary. After deploying, build with
  /// `--dart-define=CLOUDINARY_SERVER_DELETES=true` to turn them on.
  static const serverDeletesEnabled = bool.fromEnvironment(
    'CLOUDINARY_SERVER_DELETES',
  );

  /// Deletes an asset from Cloudinary.
  ///
  /// Cloudinary only accepts signed deletes, and the API secret must not ship
  /// in the app, so this calls the `deleteCloudinaryAsset` Cloud Function
  /// (functions/index.js), which checks the caller is an admin.
  /// Does nothing while [serverDeletesEnabled] is false.
  /// Throws [FirebaseFunctionsException] if the delete is refused or fails.
  Future<void> deleteAsset(
    String publicId, {
    String resourceType = 'image',
  }) async {
    if (!serverDeletesEnabled) {
      if (kDebugMode) {
        debugPrint('Cloudinary delete skipped (server deletes off)');
      }
      return;
    }
    await FirebaseFunctions.instance
        .httpsCallable('deleteCloudinaryAsset')
        .call<Map<String, dynamic>>({
          'publicId': publicId,
          'resourceType': resourceType,
        });
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  final String cloudName = 'delnnzcph';
  final String uploadPreset = 'flutter_upload';

  /// Upload image and return BOTH secure_url and public_id
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

  Future<Map<String, dynamic>?> uploadBytes(
    List<int> bytes, {
    required String filename,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/${_isVideo(filename) ? "video" : "image"}/upload',
      ),
    );

    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      var jsonResp = json.decode(respStr);

      return {
        "secure_url": jsonResp['secure_url'],
        "public_id": jsonResp['public_id'],
      };
    } else {
      debugPrint('Upload failed: ${response.statusCode}');
      return null;
    }
  }

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
      debugPrint('Cloudinary delete skipped (server deletes off): $publicId');
      return;
    }
    await FirebaseFunctions.instance
        .httpsCallable('deleteCloudinaryAsset')
        .call<Map<String, dynamic>>({
          'publicId': publicId,
          'resourceType': resourceType,
        });
  }

  /// Alias for deleteAsset for backward compatibility
  Future<void> deleteImage(String publicId) =>
      deleteAsset(publicId, resourceType: 'image');
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../services/booking_service.dart';
import '../services/cloudinary_service.dart';

enum ConditionCaptureMode { pickup, returnMode }

class CarConditionCaptureScreen extends StatefulWidget {
  final String bookingId;
  final ConditionCaptureMode mode;

  const CarConditionCaptureScreen({
    super.key,
    required this.bookingId,
    required this.mode,
  });

  @override
  State<CarConditionCaptureScreen> createState() =>
      _CarConditionCaptureScreenState();
}

class _CarConditionCaptureScreenState extends State<CarConditionCaptureScreen> {
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();
  VideoPlayerController? _videoController;

  File? _videoFile;
  bool _processing = false;
  String? _error;

  bool get _isPickup => widget.mode == ConditionCaptureMode.pickup;

  String get _title => _isPickup
      ? 'Record Car Condition (Pickup)'
      : 'Record Car Condition (Return)';

  @override
  void dispose() {
    unawaited(_videoController?.dispose());
    super.dispose();
  }

  Future<void> _captureVideo(ImageSource source) async {
    setState(() {
      _error = null;
    });

    final video = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );

    if (video == null || !mounted) return;

    final file = File(video.path);
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'Could not open video: $e');
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _videoFile = file;
      unawaited(_videoController?.dispose());
      _videoController = controller;
    });
  }

  void _showCaptureOptions() {
    unawaited(
      showModalBottomSheet(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record video'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_captureVideo(ImageSource.camera));
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_captureVideo(ImageSource.gallery));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_videoFile == null) {
      setState(() => _error = 'Please record or select a video first');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final upload = await _cloudinary.uploadVideo(_videoFile!);
      if (upload == null) {
        throw Exception('Failed to upload video');
      }

      await BookingService.recordConditionVideo(
        bookingId: widget.bookingId,
        videoUrl: upload['secure_url']?.toString() ?? '',
        videoPublicId: upload['public_id']?.toString() ?? '',
        isPickup: _isPickup,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Please record a video around the car to document its current condition.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Record or select video',
              child: GestureDetector(
                onTap: _processing ? null : _showCaptureOptions,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      _videoController != null &&
                          _videoController!.value.isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                            IconButton(
                              tooltip: _videoController!.value.isPlaying
                                  ? 'Pause'
                                  : 'Play',
                              icon: Icon(
                                _videoController!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 50,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  unawaited(
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play(),
                                  );
                                });
                              },
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam,
                              size: 64,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to record or select video',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: _processing ? null : _submit,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: const Text('Submit Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

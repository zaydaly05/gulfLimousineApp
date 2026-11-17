import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/booking_service.dart';
import '../services/cloudinary_service.dart';
import '../services/km_billing_service.dart';
import '../services/odometer_service.dart';
import '../l10n/locale_service.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_feedback.dart';

enum OdometerCaptureMode { start, end }

class OdometerCaptureScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;
  final OdometerCaptureMode mode;

  const OdometerCaptureScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
    required this.mode,
  });

  @override
  State<OdometerCaptureScreen> createState() => _OdometerCaptureScreenState();
}

class _OdometerCaptureScreenState extends State<OdometerCaptureScreen> {
  final _kmController = TextEditingController();
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();

  // Bytes rather than dart:io File so the screen also works on the web.
  Uint8List? _imageFile;
  String? _uploadedUrl;
  String? _uploadedPublicId;
  bool _processing = false;
  bool _ocrRunning = false;
  String? _error;

  bool get _isStart => widget.mode == OdometerCaptureMode.start;

  String get _title =>
      _isStart ? tr('recordPickupOdometer') : tr('recordReturnOdometer');

  int get _rentalDays {
    final days = widget.bookingData['days'];
    if (days is num) return days.toInt().clamp(1, 3650);
    return 1;
  }

  int? get _startKm {
    final odometer = widget.bookingData['odometer'];
    if (odometer is Map) {
      final v = odometer['startKm'];
      if (v is num) return v.toInt();
    }
    return null;
  }

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto(ImageSource source) async {
    setState(() {
      _error = null;
    });

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _imageFile = bytes;
      _uploadedUrl = null;
      _uploadedPublicId = null;
      _ocrRunning = true;
    });

    final detected = await OdometerService.extractKmFromImage(bytes);

    if (!mounted) return;
    setState(() {
      _ocrRunning = false;
      if (detected != null) {
        _kmController.text = detected.toString();
      }
    });

    if (detected == null && mounted) {
      ScaffoldMessenger.of(context)
          .showInfo(tr('couldNotReadOdometerAutomatically'));
    }
  }

  void _showCaptureOptions() {
    unawaited(
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(tr('takePhoto2')),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_capturePhoto(ImageSource.camera));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(tr('chooseFromGallery')),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(_capturePhoto(ImageSource.gallery));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final kmText = _kmController.text.trim().replaceAll(',', '');
    final km = int.tryParse(kmText);
    if (km == null || km <= 0) {
      setState(() => _error = tr('enterValidOdometer'));
      return;
    }

    if (_imageFile == null) {
      setState(() => _error = tr('photoOdometerFirst'));
      return;
    }

    if (!_isStart) {
      final start = _startKm;
      if (start != null && km < start) {
        setState(() => _error = tr('returnReadingMin', args: {'km': '$start'}));
        return;
      }
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      String photoUrl = _uploadedUrl ?? '';
      String photoPublicId = _uploadedPublicId ?? '';

      if (photoUrl.isEmpty) {
        final bytes = _imageFile!;
        final upload = await _cloudinary.uploadBytes(
          bytes,
          filename: 'odometer_${widget.bookingId}.jpg',
        );
        if (upload == null) {
          throw Exception(tr('failedUploadPhoto'));
        }
        photoUrl = upload['secure_url']?.toString() ?? '';
        photoPublicId = upload['public_id']?.toString() ?? '';
      }

      if (_isStart) {
        await BookingService.recordStartKm(
          bookingId: widget.bookingId,
          km: km,
          photoUrl: photoUrl,
          photoPublicId: photoPublicId,
        );
      } else {
        await BookingService.recordEndKmAndFinalize(
          bookingId: widget.bookingId,
          km: km,
          photoUrl: photoUrl,
          photoPublicId: photoPublicId,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = friendlyError(e);
      });
    }
  }

  Widget _buildBillingPreview() {
    if (_isStart) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          tr(
            'allowanceKmKmDayS',
            args: {
              'allowedKm': '${KmBillingService.allowedKm(_rentalDays)}',
              'kmPerDay': '${KmBillingService.kmPerDay}',
              '_rentalDays': '$_rentalDays',
              'toStringAsFixed': KmBillingService.extraKmRateEgp
                  .toStringAsFixed(0),
            },
          ),
          style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
        ),
      );
    }

    final start = _startKm;
    final endText = _kmController.text.trim().replaceAll(',', '');
    final end = int.tryParse(endText);
    if (start == null || end == null || end < start) {
      return const SizedBox.shrink();
    }

    final billing = KmBillingService.calculate(
      startKm: start,
      endKm: end,
      rentalDays: _rentalDays,
    );
    final base = (widget.bookingData['total_amount'] as num?)?.toDouble() ?? 0;
    final finalAmount = KmBillingService.finalAmount(
      baseAmount: base,
      billing: billing,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: billing.extraKm > 0
            ? Colors.orange.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('drivenKm', args: {'drivenKm': '${billing.drivenKm}'})),
          Text(tr('allowedKm', args: {'allowedKm': '${billing.allowedKm}'})),
          Text(
            tr(
              'extraKmEgpEgp',
              args: {
                'extraKm': '${billing.extraKm}',
                'toStringAsFixed': KmBillingService.extraKmRateEgp
                    .toStringAsFixed(0),
                'toStringAsFixed2': billing.extraKmChargeEgp.toStringAsFixed(0),
              },
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: billing.extraKm > 0
                  ? Colors.orange.shade900
                  : Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'finalTotalEgpBaseEgp',
              args: {
                'toStringAsFixed': finalAmount.toStringAsFixed(0),
                'toStringAsFixed1': base.toStringAsFixed(0),
              },
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isStart ? tr('photoOdometerReceive') : tr('photoOdometerReturn'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: tr('captureOdometerPhoto'),
              child: GestureDetector(
                onTap: _processing ? null : _showCaptureOptions,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageFile != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_imageFile!, fit: BoxFit.cover),
                            if (_ocrRunning)
                              Container(
                                color: Colors.black45,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        tr('readingOdometer'),
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.speed,
                              size: 48,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('tapToCaptureOdometerPhoto'),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kmController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('odometerReadingKm'),
                hintText: _isStart ? 'e.g. 45230' : 'e.g. 45450',
                border: const OutlineInputBorder(),
                suffixText: 'km',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (!_isStart && _startKm != null) ...[
              const SizedBox(height: 8),
              Text(
                tr('pickupReadingKm', args: {'_startKm': '$_startKm'}),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            _buildBillingPreview(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _processing ? null : _submit,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isStart ? Icons.login : Icons.logout),
              label: Text(
                _isStart ? tr('confirmPickupKm') : tr('confirmReturnKm'),
              ),
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

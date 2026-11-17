import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../utils/safe_insets.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class RentalAgreementScreen extends StatefulWidget {
  final String? bookingId;
  final Map<String, dynamic>? bookingData;
  final RentalDetails? rentalDetails;

  const RentalAgreementScreen({
    super.key,
    this.bookingId,
    this.bookingData,
    this.rentalDetails,
  });

  @override
  State<RentalAgreementScreen> createState() => _RentalAgreementScreenState();
}

class _RentalAgreementScreenState extends State<RentalAgreementScreen> {
  bool _accepted = false;
  bool _submitting = false;

  Future<void> _sign() async {
    if (!_accepted) return;

    // If it's a pre-booking signature, we don't need to call the service yet.
    if (widget.bookingId == null) {
      Navigator.pop(context, 'digital_signature_accepted');
      return;
    }

    setState(() => _submitting = true);
    try {
      await BookingService.signRentalAgreement(
        bookingId: widget.bookingId!,
        signatureUrl: 'digital_signature_accepted',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showError(e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String carName = tr('carFallback');
    if (widget.bookingData != null) {
      carName =
          widget.bookingData!['carName'] ??
          widget.bookingData!['car_name'] ??
          tr('carFallback');
    } else if (widget.rentalDetails != null) {
      carName = widget.rentalDetails!.carName;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('rentalAgreement')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20).withSafeBottom(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('rentalTermsConditions'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                tr('t1UseOfVehicleThe', args: {'carName': carName}),
                style: TextStyle(height: 1.5, color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: Text(
                tr('iHaveReadAndAgree'),
                style: TextStyle(fontSize: 13),
              ),
              activeColor: Colors.orange,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _accepted && !_submitting ? _sign : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      tr('signStartRental'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

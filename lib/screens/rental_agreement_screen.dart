import 'package:flutter/material.dart';
import '../services/booking_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String carName = 'Car';
    if (widget.bookingData != null) {
      carName = widget.bookingData!['carName'] ?? widget.bookingData!['car_name'] ?? 'Car';
    } else if (widget.rentalDetails != null) {
      carName = widget.rentalDetails!.carName;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Agreement'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'RENTAL TERMS & CONDITIONS',
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
                '1. USE OF VEHICLE: The Renter shall use the $carName only for personal transport and shall not use it for illegal purposes.\n\n'
                '2. GPS TRACKING: The vehicle is equipped with a GPS tracking device. The Owner reserves the right to monitor the vehicle\'s location at all times for security reasons.\n\n'
                '3. SAFE ZONE: The Renter agrees to keep the vehicle within the designated Safe Zone (100km radius from Cairo). Leaving this zone may trigger security alerts.\n\n'
                '4. THEFT & LOSS: In the event of theft, the Renter must immediately notify the Owner and the police. The Renter is legally responsible for the full value of the vehicle if theft occurs due to negligence.\n\n'
                '5. REMOTE LOCK: The Owner reserves the right to remotely immobilize the vehicle if any suspicious activity is detected or terms are breached.',
                style: TextStyle(height: 1.5, color: Colors.grey.shade800),
              ),
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: const Text(
                'I have read and agree to the terms of the digital rental agreement. I understand a copy will be sent to my email.',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Sign & Start Rental',
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

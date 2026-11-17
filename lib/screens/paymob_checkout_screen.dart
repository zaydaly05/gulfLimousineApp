import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/paymob_service.dart';
import '../services/payments_server_client.dart';
import '../theme/app_theme.dart';
import 'payment_success_screen.dart';

/// Opens Paymob's hosted checkout for a booking and waits for the result.
///
/// The booking is only marked paid by payments_server when Paymob's signed
/// callback arrives, so this screen watches the booking document rather
/// than trusting the browser redirect.
class PaymobCheckoutScreen extends StatefulWidget {
  const PaymobCheckoutScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    this.method,
  });

  final String bookingId;
  final double amount;

  /// 'card' or 'wallet'; null lets the customer choose on Paymob's page.
  final String? method;

  @override
  State<PaymobCheckoutScreen> createState() => _PaymobCheckoutScreenState();
}

class _PaymobCheckoutScreenState extends State<PaymobCheckoutScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bookingSub;
  String _paymentStatus = 'unpaid';
  bool _opening = false;
  bool _testMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen(
          _onBooking,
          onError: (Object e) {
            if (mounted) setState(() => _error = 'Could not load booking: $e');
          },
        );
    unawaited(_openCheckout());
  }

  @override
  void dispose() {
    unawaited(_bookingSub?.cancel());
    super.dispose();
  }

  void _onBooking(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;
    final status = (snapshot.data()?['payment_status'] ?? 'unpaid').toString();
    if (status == 'paid') {
      unawaited(
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PaymentSuccessScreen(
              message:
                  'Thank you for choosing Gulf Limousine Travel.\n'
                  'Your payment was received and your car is booked.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _paymentStatus = status);
  }

  Future<void> _openCheckout() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final checkout = await PaymobService.startCheckout(
        widget.bookingId,
        method: widget.method,
      );
      if (!mounted) return;
      setState(() => _testMode = checkout.testMode);
      final opened = await launchUrl(
        checkout.url,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!opened && mounted) {
        setState(() => _error = 'Could not open the payment page.');
      }
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Payment could not be started: $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = _paymentStatus == 'failed';
    return Scaffold(
      appBar: AppBar(title: const Text('Online Payment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              failed ? Icons.error_outline : Icons.lock_clock,
              size: 72,
              color: failed ? Colors.red : AppTheme.accent,
            ),
            const SizedBox(height: 16),
            Text(
              failed
                  ? 'The payment did not go through'
                  : 'Complete the payment on the Paymob page',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: EGP ${widget.amount.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              failed
                  ? 'No money was taken. You can try again or choose '
                        'another payment method from My Bookings.'
                  : 'This screen updates by itself once Paymob confirms '
                        'the payment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (!failed && _error == null) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_testMode) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.amber.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Test mode, no real money: pay with wallet 01010101010 '
                    '(MPIN and OTP 123456) or a Paymob test card.',
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _opening ? null : _openCheckout,
              icon: const Icon(Icons.open_in_new),
              label: Text(failed ? 'Try Again' : 'Open Payment Page'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Pay Later'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_service.dart';
import '../widgets/expandable_address_row.dart';
import 'card_payment.dart';
import 'instapay_screen.dart';
import 'payment_success_screen.dart';
import 'rental_agreement_screen.dart';
import 'wallet_payment_screen.dart';
import '../widgets/payment_method_tile.dart';

class PaymentScreen extends StatefulWidget {
  final RentalDetails rental;

  const PaymentScreen({super.key, required this.rental});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _signatureUrl;

  Future<void> _payWithMethod(String method, Widget screen) async {
    if (_isProcessing) return;
    if (_signatureUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign the rental agreement first')),
      );
      return;
    }
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result != null && mounted) {
      await _completePayment(
        method,
        reference: result is String ? result : null,
      );
    }
  }

  Future<void> _completePayment(String method, {String? reference}) async {
    // Guards against a double tap creating two bookings.
    if (_isProcessing) return;
    if (_signatureUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign the rental agreement first')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final status = method == 'cash' ? 'pending' : 'paid';
      await BookingService.completeRental(
        rental: widget.rental,
        paymentMethod: method,
        paymentStatus: status,
        signatureUrl: _signatureUrl,
        paymentReference: reference,
      );
      if (!mounted) return;
      final isCash = method == 'cash';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            title: isCash ? 'Order Confirmed' : 'Payment Successful',
            message: isCash
                ? 'Thank you for choosing Gulf Limousine Travel.\nPay cash when you collect the car.'
                : 'Thank you for choosing Gulf Limousine Travel.\nYour car has been successfully booked.',
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rental = widget.rental;
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    children: [
                      _summaryRow('Car', rental.carName),
                      if (rental.brand.isNotEmpty)
                        _summaryRow('Brand', rental.brand),
                      _summaryRow('Pickup', dateFmt.format(rental.pickupDate)),
                      _summaryRow('Return', dateFmt.format(rental.returnDate)),
                      if (rental.pickupLocation != null)
                        ExpandableAddressRow(
                          label: 'Pickup location',
                          address: rental.pickupLocation!.address,
                          icon: Icons.place,
                        ),
                      if (rental.dropoffLocation != null)
                        ExpandableAddressRow(
                          label: 'Drop-off location',
                          address: rental.dropoffLocation!.address,
                          icon: Icons.flag,
                          iconColor: Colors.blue,
                        ),
                      _summaryRow('Duration', '${rental.days} day(s)'),
                      _summaryRow(
                        'Rate',
                        'EGP ${rental.pricePerDay.toStringAsFixed(0)} / day',
                      ),
                      const Divider(height: 24),
                      _summaryRow(
                        'Total',
                        'EGP ${rental.totalAmount.toStringAsFixed(0)}',
                        bold: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Legal Agreement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: _signatureUrl != null
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    child: ListTile(
                      leading: Icon(
                        _signatureUrl != null
                            ? Icons.verified
                            : Icons.assignment_late,
                        color: _signatureUrl != null
                            ? Colors.green
                            : Colors.blue,
                      ),
                      title: Text(
                        _signatureUrl != null
                            ? 'Rental Agreement Signed'
                            : 'Sign Rental Agreement',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _signatureUrl != null
                              ? Colors.green.shade900
                              : Colors.blue.shade900,
                        ),
                      ),
                      subtitle: Text(
                        _signatureUrl != null
                            ? 'A copy will be sent to your email.'
                            : 'Mandatory before booking confirmation',
                      ),
                      trailing: _signatureUrl != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        final sig = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RentalAgreementScreen(rentalDetails: rental),
                          ),
                        );
                        if (sig != null && mounted) {
                          setState(() => _signatureUrl = sig);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _signatureUrl != null ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        PaymentMethodTile(
                          icon: Icons.credit_card,
                          title: 'Credit / Debit Card',
                          onTap: () => _payWithMethod(
                            'card',
                            CardPaymentScreen(amount: rental.totalAmount),
                          ),
                        ),
                        PaymentMethodTile(
                          icon: Icons.account_balance_wallet,
                          title: 'Mobile Wallet',
                          onTap: () => _payWithMethod(
                            'wallet',
                            WalletPaymentScreen(amount: rental.totalAmount),
                          ),
                        ),
                        PaymentMethodTile(
                          icon: Icons.phone_android,
                          title: 'InstaPay',
                          onTap: () => _payWithMethod(
                            'instapay',
                            InstaPayScreen(amount: rental.totalAmount),
                          ),
                        ),
                        PaymentMethodTile(
                          icon: Icons.money,
                          title: 'Cash on Pickup',
                          subtitle: 'Pay when you collect the car',
                          onTap: () => _completePayment('cash'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 18 : 14,
              color: bold ? const Color(0xFFFF8C00) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Widget> children;

  const _SummaryCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

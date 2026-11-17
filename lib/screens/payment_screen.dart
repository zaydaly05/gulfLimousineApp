import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:async';

import '../services/app_config_service.dart';
import '../services/booking_service.dart';
import '../utils/payment_validation.dart';
import '../widgets/expandable_address_row.dart';
import 'card_payment.dart';
import 'instapay_screen.dart';
import 'payment_success_screen.dart';
import 'paymob_checkout_screen.dart';
import 'rental_agreement_screen.dart';
import 'wallet_payment_screen.dart';
import '../widgets/payment_method_tile.dart';
import '../theme/app_theme.dart';
import '../l10n/locale_service.dart';
import '../l10n/content_labels.dart';
import '../widgets/app_feedback.dart';

class PaymentScreen extends StatefulWidget {
  final RentalDetails rental;

  const PaymentScreen({super.key, required this.rental});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _signatureUrl;

  /// Null until loaded; decides whether online (Paymob) payment is offered.
  AppConfig? _config;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final config = await AppConfigService.instance.load();
    if (mounted) setState(() => _config = config);
  }

  bool _ensureSigned() {
    if (_signatureUrl != null) return true;
    ScaffoldMessenger.of(context).showInfo(tr('pleaseSignTheRentalAgreement'));
    return false;
  }

  Future<void> _payWithMethod(String method, Widget screen) async {
    if (_isProcessing || !_ensureSigned()) return;
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (result == null || !mounted) return;
    if (result is ManualPaymentResult) {
      // InstaPay / wallet transfer: an admin confirms it later.
      await _completePayment(
        method,
        reference: result.reference,
        payerPhone: result.payerPhone,
      );
    } else {
      await _completePayment(method);
    }
  }

  /// Card or wallet checkout on Paymob's hosted page. The booking is
  /// created first (unpaid); Paymob's signed callback to payments_server
  /// marks it paid, and [PaymobCheckoutScreen] waits for that.
  Future<void> _payOnline(String method) async {
    if (_isProcessing || !_ensureSigned()) return;
    setState(() => _isProcessing = true);
    try {
      final bookingId = await BookingService.completeRental(
        rental: widget.rental,
        paymentMethod: 'paymob',
        paymobMethod: method,
        signatureUrl: _signatureUrl!,
      );
      if (!mounted) return;
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymobCheckoutScreen(
            bookingId: bookingId,
            amount: widget.rental.totalAmount,
            method: method,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _completePayment(
    String method, {
    String? reference,
    String? payerPhone,
  }) async {
    // Guards against a double tap creating two bookings.
    if (_isProcessing || !_ensureSigned()) return;

    setState(() => _isProcessing = true);
    try {
      await BookingService.completeRental(
        rental: widget.rental,
        paymentMethod: method,
        signatureUrl: _signatureUrl!,
        paymentReference: reference,
        payerPhone: payerPhone,
      );
      if (!mounted) return;
      final (title, message) = switch (method) {
        'cash' => (tr('orderConfirmed'), tr('thanksCash')),
        'instapay' ||
        'wallet' => (tr('paymentSubmitted'), tr('thanksTransfer')),
        _ => (tr('paymentSuccessful'), tr('thanksBooked')),
      };
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(title: title, message: message),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rental = widget.rental;
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: Text(tr('checkout'))),
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
                  Text(
                    tr('bookingSummary'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    children: [
                      _summaryRow(tr('carFallback'), rental.carName),
                      if (rental.brand.isNotEmpty)
                        _summaryRow(tr('brand'), rental.brand),
                      _summaryRow(
                        tr('pickup'),
                        dateFmt.format(rental.pickupDate),
                      ),
                      _summaryRow(
                        tr('returnDate'),
                        dateFmt.format(rental.returnDate),
                      ),
                      if (rental.pickupLocation != null)
                        ExpandableAddressRow(
                          label: tr('pickupLocation2'),
                          address: rental.pickupLocation!.address,
                          icon: Icons.place,
                        ),
                      if (rental.dropoffLocation != null)
                        ExpandableAddressRow(
                          label: tr('dropOffLocation'),
                          address: rental.dropoffLocation!.address,
                          icon: Icons.flag,
                          iconColor: Colors.blue,
                        ),
                      _summaryRow(
                        tr('duration'),
                        tr('daysCount', args: {'n': '${rental.days}'}),
                      ),
                      _summaryRow(tr('carsLabel'), '${rental.quantity}'),
                      if (rental.colorPreferences.isNotEmpty)
                        _summaryRow(
                          tr('coloursPreferredFirst'),
                          rental.colorPreferences.map(colourLabel).join(' › '),
                        ),
                      _summaryRow(
                        tr('rate'),
                        tr(
                              'egpPerDay',
                              args: {
                                'amount': rental.pricePerDay.toStringAsFixed(0),
                              },
                            ) +
                            (rental.quantity > 1 ? ' ${tr('perCar')}' : ''),
                      ),
                      const Divider(height: 24),
                      _summaryRow(
                        tr('total'),
                        egp(rental.totalAmount),
                        bold: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('legalAgreement'),
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
                            ? tr('agreementSignedTitle')
                            : tr('signAgreement'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _signatureUrl != null
                              ? Colors.green.shade900
                              : Colors.blue.shade900,
                        ),
                      ),
                      subtitle: Text(
                        _signatureUrl != null
                            ? tr('copySentEmail')
                            : tr('mandatoryBeforeBooking'),
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
                  Text(
                    tr('paymentMethod'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Opacity(
                    opacity: _signatureUrl != null ? 1.0 : 0.5,
                    child: _paymentMethods(rental),
                  ),
                ],
              ),
            ),
    );
  }

  /// The payment methods the admin has switched on.
  Widget _paymentMethods(RentalDetails rental) {
    final config = _config;
    if (config == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final online = config.hasPaymob;
    final tiles = [
      if (config.isEnabled('card'))
        PaymentMethodTile(
          icon: Icons.credit_card,
          title: tr('card'),
          subtitle: online ? tr('secureCheckoutPaymob') : null,
          onTap: () => online
              ? _payOnline('card')
              : _payWithMethod(
                  'card',
                  CardPaymentScreen(amount: rental.totalAmount),
                ),
        ),
      if (online && config.isEnabled('walletOnline'))
        PaymentMethodTile(
          icon: Icons.bolt,
          title: tr('mobileWalletInstant'),
          subtitle: tr('vodafoneCashOrangeEWe'),
          onTap: () => _payOnline('wallet'),
        ),
      if (config.isEnabled('walletTransfer'))
        PaymentMethodTile(
          icon: Icons.account_balance_wallet,
          title: tr('mobileWalletTransfer'),
          subtitle: tr('sendToOurWalletWe'),
          onTap: () => _payWithMethod(
            'wallet',
            WalletPaymentScreen(amount: rental.totalAmount),
          ),
        ),
      if (config.isEnabled('instapay'))
        PaymentMethodTile(
          icon: Icons.phone_android,
          title: tr('instapay'),
          subtitle: tr('transferToOurInstapayAddress'),
          onTap: () => _payWithMethod(
            'instapay',
            InstaPayScreen(amount: rental.totalAmount),
          ),
        ),
      if (config.isEnabled('cash'))
        PaymentMethodTile(
          icon: Icons.money,
          title: tr('cashPickup'),
          subtitle: tr('cashPickupHint'),
          onTap: () => _completePayment('cash'),
        ),
    ];
    if (tiles.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          tr('noPaymentMethodsAreAvailable'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(children: tiles);
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Long labels or values wrap instead of running into each other;
          // values stay at the end of the row.
          Flexible(
            flex: 3,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 18 : 14,
                color: bold ? AppTheme.accent : null,
              ),
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

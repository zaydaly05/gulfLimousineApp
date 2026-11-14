import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/traffic_violation_service.dart';
import 'card_payment.dart';
import 'instapay_screen.dart';
import 'payment_success_screen.dart';
import 'wallet_payment_screen.dart';
import '../l10n/locale_service.dart';

class MyTrafficViolationsScreen extends StatelessWidget {
  const MyTrafficViolationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text(context.t('signInTickets'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('trafficTickets'))),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: _UserViolationsList(user: user),
      ),
    );
  }
}

class _UserViolationsList extends StatelessWidget {
  final User user;

  const _UserViolationsList({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TrafficViolationService.watchForUserId(user.uid),
      builder: (context, byId) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: (user.email ?? '').isEmpty
              ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
              : TrafficViolationService.watchForEmail(user.email!),
          builder: (context, byEmail) {
            final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final doc in [...?byId.data?.docs, ...?byEmail.data?.docs]) {
              merged[doc.id] = doc;
            }
            final docs = merged.values.where((doc) {
              return (doc.data()['status'] ?? '') != 'waived';
            }).toList()
              ..sort((a, b) {
                final aDate = a.data()['createdAt'];
                final bDate = b.data()['createdAt'];
                if (aDate is Timestamp && bDate is Timestamp) {
                  return bDate.compareTo(aDate);
                }
                return 0;
              });

            if (byId.connectionState == ConnectionState.waiting &&
                docs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          context.t('noTickets'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final status = (data['status'] ?? 'pending').toString();
                final pending = status == 'pending';
                final awaitingCash =
                    pending && (data['payment_method'] ?? '') == 'cash';
                final date = data['violationDate'];
                final dateLabel = date is Timestamp
                    ? DateFormat('dd MMM yyyy').format(date.toDate())
                    : '';
                final amount = TrafficViolationService.amountOf(data);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gavel, color: Color(0xFFFF8C00)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['car_name']?.toString() ?? context.t('cars'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              awaitingCash
                                  ? 'CASH PENDING'
                                  : pending
                                      ? context.t('unpaid').toUpperCase()
                                      : context.t(status.toLowerCase()).toUpperCase(),
                              style: TextStyle(
                                color: pending
                                    ? Colors.orange
                                    : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'EGP ${amount.toStringAsFixed(0)}'
                          '${dateLabel.isEmpty ? '' : ' · $dateLabel'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF8C00),
                          ),
                        ),
                        if ((data['ticketNumber'] ?? '').toString().isNotEmpty)
                          Text('Ticket: ${data['ticketNumber']}'),
                        if ((data['description'] ?? '').toString().isNotEmpty)
                          Text('${data['description']}'),
                        if ((data['location'] ?? '').toString().isNotEmpty)
                          Text('${context.t('location')}: ${data['location']}'),
                        if (awaitingCash) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Cash payment submitted. Waiting for office confirmation.',
                          ),
                        ],
                        if (pending && !awaitingCash) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C00),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViolationPaymentScreen(
                                      violationId: doc.id,
                                      data: data,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                context.t('payNow'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ViolationPaymentScreen extends StatefulWidget {
  final String violationId;
  final Map<String, dynamic> data;

  const ViolationPaymentScreen({
    super.key,
    required this.violationId,
    required this.data,
  });

  @override
  State<ViolationPaymentScreen> createState() => _ViolationPaymentScreenState();
}

class _ViolationPaymentScreenState extends State<ViolationPaymentScreen> {
  bool _isProcessing = false;

  double get _amount => TrafficViolationService.amountOf(widget.data);

  Future<void> _payWithMethod(String method, Widget screen) async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (confirmed == true) {
      await _completePayment(method, paid: true);
    }
  }

  Future<void> _completePayment(String method, {required bool paid}) async {
    setState(() => _isProcessing = true);
    try {
      await TrafficViolationService.pay(
        violationId: widget.violationId,
        paymentMethod: method,
        paymentStatus: paid ? 'paid' : 'pending',
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            title: paid ? 'Ticket paid' : 'Cash payment recorded',
            message: paid
                ? 'Your traffic violation of EGP ${_amount.toStringAsFixed(0)} has been paid.'
                : 'Pay cash at the office. An admin will confirm your traffic ticket payment.',
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.data['violationDate'];
    final dateLabel = date is Timestamp
        ? DateFormat('dd MMM yyyy').format(date.toDate())
        : '';

    return Scaffold(
      appBar: AppBar(title: Text(context.t('ticketSummary'))),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Text(
                  context.t('ticketSummary'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row(context.t('cars'), widget.data['car_name']?.toString() ?? context.t('cars')),
                        if (dateLabel.isNotEmpty) _row(context.t('pickupDate'), dateLabel),
                        if ((widget.data['ticketNumber'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _row('Ticket', widget.data['ticketNumber'].toString()),
                        if ((widget.data['description'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _row(
                            context.t('details'),
                            widget.data['description'].toString(),
                          ),
                        const Divider(height: 24),
                        _row(
                          context.t('amountDue'),
                          'EGP ${_amount.toStringAsFixed(0)}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  context.t('paymentMethod'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _method(
                  Icons.credit_card,
                  context.t('card'),
                  () => _payWithMethod(
                    'card',
                    CardPaymentScreen(amount: _amount),
                  ),
                ),
                _method(
                  Icons.account_balance_wallet,
                  context.t('wallet'),
                  () => _payWithMethod(
                    'wallet',
                    WalletPaymentScreen(amount: _amount),
                  ),
                ),
                _method(
                  Icons.phone_android,
                  context.t('instapay'),
                  () => _payWithMethod(
                    'instapay',
                    InstaPayScreen(amount: _amount),
                  ),
                ),
                _method(
                  Icons.money,
                  context.t('cashPickup'),
                  () => _completePayment('cash', paid: false),
                  subtitle: context.t('cashPickupHint'),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 18 : 14,
                color: bold ? const Color(0xFFFF8C00) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _method(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFF8C00).withValues(alpha: 0.15),
          child: Icon(icon, color: const Color(0xFFFF8C00)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

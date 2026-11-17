import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../l10n/locale_service.dart';
import '../services/booking_service.dart';
import '../widgets/language_picker.dart';
import '../widgets/empty_state.dart';
import '../utils/safe_insets.dart';

class ViewPaymentsScreen extends StatefulWidget {
  const ViewPaymentsScreen({super.key});

  @override
  State<ViewPaymentsScreen> createState() => _ViewPaymentsScreenState();
}

class _ViewPaymentsScreenState extends State<ViewPaymentsScreen> {
  // Streams are created once (late = on first use), not in build():
  // a rebuild (e.g. language change) would otherwise reopen the
  // Firestore listener and flash the loading spinner.
  final _paymentsStream = FirebaseFirestore.instance
      .collection('payments')
      .orderBy('payment_date', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Navigator.canPop(context)
            ? const BackButton(color: Colors.orange)
            : null,
        title: Text(context.t('paymentsTitle')),
        actions: const [
          LanguageToggleButton(dark: true, showText: false),
          SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 PAYMENTS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _paymentsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: context.t('noPayments'),
                      dark: true,
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16)
                        .withSafeBottom(context),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final payment = doc.data() as Map<String, dynamic>;

                      final paidAt = payment['payment_date'];
                      final formattedDate = paidAt is Timestamp
                          ? DateFormat('dd MMM yyyy - hh:mm a')
                                .format(paidAt.toDate())
                          : '';

                      Color statusColor = Colors.orange;
                      final st = (payment['status'] ?? '').toString();
                      if (st == "paid") {
                        statusColor = Colors.green;
                      } else if (st == "failed" || st == "rejected") {
                        statusColor = Colors.red;
                      }
                      final reference = (payment['reference'] ?? '').toString();
                      final payerPhone = (payment['payer_phone'] ?? '')
                          .toString();

                      return Card(
                        color: Colors.grey.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    egp(payment['amount']),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      context
                                          .t(
                                            st.isEmpty
                                                ? 'status'
                                                : st.toLowerCase(),
                                          )
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "${context.t('email')}: ${payment['user_email']}",
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              Text(
                                "${context.t('paymentMethod')}: ${paymentMethodLabel('${payment['method']}')}",
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              Text(
                                '${tr('date')}: $formattedDate',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              if (reference.isNotEmpty)
                                SelectableText(
                                  "${context.t('transactionId')}: $reference",
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              if (payerPhone.isNotEmpty)
                                SelectableText(
                                  "${context.t('sentFrom')}: $payerPhone",
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              // Manual transfers: the admin checks the
                              // InstaPay/wallet statement, then decides.
                              if (st == 'awaiting_verification') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _verify(
                                          context,
                                          doc.id,
                                          payment,
                                          approved: false,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: Text(context.t('reject')),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _verify(
                                          context,
                                          doc.id,
                                          payment,
                                          approved: true,
                                        ),
                                        child: Text(
                                          context.t('confirmReceived'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify(
    BuildContext context,
    String paymentId,
    Map<String, dynamic> payment, {
    required bool approved,
  }) async {
    final bookingId = (payment['booking_id'] ?? '').toString();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          approved ? context.t('confirmReceived') : context.t('reject'),
        ),
        content: Text(
          approved
              ? tr(
                  'confirmOnlyAfterSee',
                  args: {'amount': egp(payment['amount'])},
                )
              : tr('customerToldNotFound'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              approved ? context.t('confirmReceived') : context.t('reject'),
            ),
          ),
        ],
      ),
    );
    if (ok != true || bookingId.isEmpty) return;
    try {
      await BookingService.verifyManualPayment(
        paymentId: paymentId,
        bookingId: bookingId,
        approved: approved,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approved ? tr('paymentConfirmed') : tr('paymentRejectedMsg'),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }
}

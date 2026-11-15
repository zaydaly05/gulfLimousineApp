import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';

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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // This screen has no AppBar, so provide the way back.
                  if (Navigator.canPop(context))
                    const BackButton(color: Colors.orange),
                  Expanded(
                    child: Text(
                      context.t('paymentsTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const LanguageToggleButton(dark: true),
                ],
              ),
            ),

            // 🔹 PAYMENTS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _paymentsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        context.t('payments'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final payment =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;

                      final paidAt = payment['payment_date'];
                      final formattedDate = paidAt is Timestamp
                          ? DateFormat('dd MMM yyyy - hh:mm a')
                                .format(paidAt.toDate())
                          : '';

                      Color statusColor = Colors.orange;
                      final st = (payment['status'] ?? '').toString();
                      if (st == "paid") {
                        statusColor = Colors.green;
                      } else if (st == "failed") {
                        statusColor = Colors.red;
                      }

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
                                    "${payment['amount']} EGP",
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
                                "${context.t('paymentMethod')}: ${payment['method']}",
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              Text(
                                "Date: $formattedDate",
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
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
}

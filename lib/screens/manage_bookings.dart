import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/admin_charts.dart';
import '../widgets/extra_km_admin_panel.dart';
import '../widgets/traffic_violations_admin_panel.dart';
import '../services/traffic_violation_service.dart';
import 'admin_security_hub.dart';
import '../services/whatsapp_service.dart';
import 'edit_booking_screen.dart';
import 'new_booking_screen.dart';
import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/live_refresh.dart';
import '../widgets/condition_video_chips.dart';
import '../widgets/status_pill.dart';
import '../services/booking_service.dart';
import '../models/fleet.dart';
import '../widgets/app_feedback.dart';

class ManageBookingsScreen extends StatefulWidget {
  const ManageBookingsScreen({super.key});

  @override
  State<ManageBookingsScreen> createState() => _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends State<ManageBookingsScreen> {
  final _bookingsStream = FirebaseFirestore.instance
      .collection('bookings')
      .snapshots();

  Future<void> _deleteBooking(BuildContext context, String id) async {
    unawaited(
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            context.t('delete'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            context.t('cannotBeUndone'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.t('cancel')),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await BookingService.deleteBooking(id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showError(e);
                  }
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(
                context.t('delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.t('manageBookingsTitle')),
        backgroundColor: Colors.black,
        actions: const [
          LanguageToggleButton(dark: true, showText: false),
          SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: context.t('newBooking'),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewBookingScreen()),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _bookingsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(
                error: snapshot.error,
                message: tr('errorLoadingBookings'),
                dark: true,
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = sortedByCreatedAtDesc(
              snapshot.data?.docs ?? const <QueryDocumentSnapshot>[],
            );
            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Text(
                        context.t('noRecentBookings'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 80 + bottomPad),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final booking = doc.data() as Map<String, dynamic>;

                final status = (booking['status'] ?? 'pending').toString();
                final statusTranslated = context.t(status.toLowerCase());
                final carName = resolveBookingCar(booking);
                final customer = resolveBookingName(booking);
                final email = booking['user_email']?.toString() ?? '';
                final pickup = formatBookingDate(
                  booking['pickupDate'] ?? booking['startDate'],
                );
                final returnDate = formatBookingDate(booking['returnDate']);
                final total = booking['total_amount'];
                final finalAmount = booking['final_amount'];
                final hasExtraKm = bookingHasExtraKmCharge(booking);

                return Card(
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_car,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                carName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            StatusPill(
                              label: statusTranslated.toUpperCase(),
                              color: bookingStatusColor(status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${context.t('customer')}: $customer',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            '${context.t('email')}: ${ltr(email)}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (Fleet.bookingSummary(booking) case final fleet
                            when fleet.isNotEmpty)
                          Text(
                            '${context.t('cars')}: $fleet',
                            style: TextStyle(color: Colors.grey.shade300),
                          ),
                        if (pickup.isNotEmpty)
                          Text(
                            '${context.t('pickup')}: $pickup',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (returnDate.isNotEmpty)
                          Text(
                            '${context.t('returnDate')}: $returnDate',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (booking['pickupLocation'] is Map &&
                            (booking['pickupLocation']['address'] ?? '')
                                .toString()
                                .isNotEmpty)
                          Text(
                            '${context.t('from')}: ${booking['pickupLocation']['address']}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (booking['dropoffLocation'] is Map &&
                            (booking['dropoffLocation']['address'] ?? '')
                                .toString()
                                .isNotEmpty)
                          Text(
                            '${context.t('to')}: ${booking['dropoffLocation']['address']}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if ((booking['chauffeurName'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text(
                            '${context.t('chauffeur')}: ${booking['chauffeurName']}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if ((booking['tripStatus'] ?? '').toString().isNotEmpty)
                          Text(
                            '${context.t('trip')}: ${statusLabel(booking['tripStatus'].toString())}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (total != null)
                          Text(
                            tr(
                              'baseRentalEgp',
                              args: {
                                'toStringAsFixed': (total as num)
                                    .toStringAsFixed(0),
                              },
                            ),
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (finalAmount != null &&
                            finalAmount != total &&
                            booking['odometer'] is Map &&
                            (booking['odometer'] as Map)['endKm'] != null)
                          Text(
                            '${context.t('finalTotal')}: ${egp(finalAmount as num)}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (hasExtraKm) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${context.t('extraKm')}: ',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: extraKmPaymentStatusColor(booking)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  extraKmPaymentStatusLabel(booking)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: extraKmPaymentStatusColor(booking),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        ExtraKmAdminPanel(
                          bookingId: doc.id,
                          booking: booking,
                          compact: true,
                        ),
                        const SizedBox(height: 8),
                        if (booking['pickupVideo'] != null ||
                            booking['returnVideo'] != null) ...[
                          Text(
                            tr('conditionVideos'),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ConditionVideoChips(
                            booking: booking,
                            carName: carName,
                          ),
                          const SizedBox(height: 8),
                        ],
                        TrafficViolationsAdminPanel(
                          sourceType: TrafficViolationService.sourceBooking,
                          rentalId: doc.id,
                          rentalData: booking,
                          compact: true,
                        ),
                        const SizedBox(height: 8),
                        if (booking['tripStatus'] == 'in_progress')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminSecurityHub(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.security,
                                color: Colors.orange,
                                size: 18,
                              ),
                              label: Text(
                                tr('liveSecurityTracking'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if ((booking['phone'] ?? '').toString().isNotEmpty)
                              IconButton(
                                tooltip: tr('whatsappCustomer'),
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Color(0xFF25D366),
                                ),
                                onPressed: () =>
                                    WhatsAppService.messageCustomer(
                                      phone: booking['phone'].toString(),
                                      customerName: customer,
                                      bookingId: doc.id,
                                    ),
                              ),
                            IconButton(
                              tooltip: tr('edit'),
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditBookingScreen(
                                      bookingId: doc.id,
                                      bookingData: booking,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: tr('delete'),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteBooking(context, doc.id),
                            ),
                          ],
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_charts.dart';
import '../widgets/extra_km_admin_panel.dart';
import '../widgets/traffic_violations_admin_panel.dart';
import '../services/traffic_violation_service.dart';
import 'video_viewer_screen.dart';
import 'admin_security_hub.dart';
import '../services/booking_service.dart';
import '../services/whatsapp_service.dart';
import 'edit_booking_screen.dart';
import 'new_booking_screen.dart';
import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';

class ManageBookingsScreen extends StatelessWidget {
  const ManageBookingsScreen({super.key});

  Future<void> _deleteBooking(BuildContext context, String id) async {
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
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(id)
                  .delete();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(
              context.t('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  List<QueryDocumentSnapshot> _sortedDocs(List<QueryDocumentSnapshot> docs) {
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = aData['createdAt'];
      final bDate = bData['createdAt'];
      if (aDate is Timestamp && bDate is Timestamp) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });
    return sorted;
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
          LanguageToggleButton(dark: true),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Text(
                        'Error loading bookings',
                        style: TextStyle(color: Colors.red.shade300),
                      ),
                    ),
                  ),
                ],
              );
            }

            final docs = _sortedDocs(snapshot.data?.docs ?? []);
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
              
              // Cleanup old videos for this booking if return date + 3 days passed
              BookingService.checkAndDeleteOldVideos(doc.id);

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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusTranslated.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status),
                              ),
                            ),
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
                          '${context.t('email')}: $email',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      if (pickup.isNotEmpty)
                        Text(
                          '${context.t('pickup')}: $pickup',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      if (returnDate.isNotEmpty)
                        Text(
                          '${context.t('return')}: $returnDate',
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
                      if ((booking['tripStatus'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Text(
                          '${context.t('trip')}: ${booking['tripStatus']}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      if (total != null)
                        Text(
                          'Base rental: EGP ${(total as num).toStringAsFixed(0)}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      if (finalAmount != null &&
                          finalAmount != total &&
                          booking['odometer'] is Map &&
                          (booking['odometer'] as Map)['endKm'] != null)
                        Text(
                          '${context.t('finalTotal')}: EGP ${(finalAmount as num).toStringAsFixed(0)}',
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
                                extraKmPaymentStatusLabel(booking).toUpperCase(),
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
                      if (booking['pickupVideo'] != null || booking['returnVideo'] != null) ...[
                        const Text(
                          'Condition Videos:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (booking['pickupVideo'] != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ActionChip(
                                  label: const Text('Pickup Video'),
                                  avatar: const Icon(Icons.play_circle_fill, size: 16),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VideoViewerScreen(
                                          url: booking['pickupVideo']['url'],
                                          title: 'Pickup Condition - $carName',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (booking['returnVideo'] != null)
                              ActionChip(
                                label: const Text('Return Video'),
                                avatar: const Icon(Icons.play_circle_fill, size: 16),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VideoViewerScreen(
                                        url: booking['returnVideo']['url'],
                                        title: 'Return Condition - $carName',
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
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
                            icon: const Icon(Icons.security, color: Colors.orange, size: 18),
                            label: const Text(
                              'LIVE SECURITY TRACKING',
                              style: TextStyle(color: Colors.white, fontSize: 12),
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
                              tooltip: 'WhatsApp Customer',
                              icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                              onPressed: () => WhatsAppService.messageCustomer(
                                phone: booking['phone'].toString(),
                                customerName: customer,
                                bookingId: doc.id,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Edit',
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
                            tooltip: 'Delete',
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

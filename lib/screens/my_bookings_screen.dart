import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/geo_location.dart';
import '../services/booking_service.dart';
import '../services/km_billing_service.dart';
import '../services/maps_launcher.dart';
import '../widgets/admin_charts.dart';
import '../services/whatsapp_service.dart';
import 'car_condition_capture_screen.dart';
import 'video_viewer_screen.dart';
import 'odometer_capture_screen.dart';
import 'rental_agreement_screen.dart';
import 'review_booking_screen.dart';
import 'track_trip_screen.dart';
import '../l10n/locale_service.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('myBookings'))),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: BookingService.userBookingsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const _BookingsFallbackByEmail();
            }

            final docs = sortedByCreatedAtDesc(
              snapshot.data?.docs ?? const <QueryDocumentSnapshot>[],
            );
            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 400, child: _EmptyBookings()),
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
                final data = doc.data() as Map<String, dynamic>;
                return _BookingCard(bookingId: doc.id, data: data);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              context.t('noBookingsYet'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('noBookingsSub'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsFallbackByEmail extends StatelessWidget {
  const _BookingsFallbackByEmail();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: BookingService.userBookingsStreamByEmail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = sortedByCreatedAtDesc(
          snapshot.data?.docs ?? const <QueryDocumentSnapshot>[],
        );
        if (docs.isEmpty) {
          return const _EmptyBookings();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _BookingCard(bookingId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const _BookingCard({required this.bookingId, required this.data});

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('cancelBookingQ')),
        content: Text(context.t('cannotBeUndone')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('keep')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.t('cancelBookingBtn'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await BookingService.cancelBooking(bookingId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('bookingCancelled'))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();
    final statusTranslated = context.t(status.toLowerCase());
    final tripStatus = (data['tripStatus'] ?? '').toString();
    final carName = resolveBookingCar(data);
    final pickup = formatBookingDate(data['pickupDate'] ?? data['startDate']);
    final returnD = formatBookingDate(data['returnDate']);
    final total = data['total_amount'];
    final days = data['days'];
    final pickupLoc = GeoLocation.tryParse(data['pickupLocation']);
    final dropoffLoc = GeoLocation.tryParse(data['dropoffLocation']);
    final hasChauffeur = (data['chauffeurId'] ?? '').toString().isNotEmpty;
    final canCancel = status == 'pending' || status == 'confirmed';
    final canTrack =
        hasChauffeur &&
        status != 'cancelled' &&
        tripStatus != 'completed' &&
        tripStatus != 'cancelled';
    final canReview = status == 'completed' && data['reviewed'] != true;

    final odometer = data['odometer'];
    final kmAllowance = data['kmAllowance'];
    final startKm = odometer is Map ? odometer['startKm'] : null;
    final endKm = odometer is Map ? odometer['endKm'] : null;
    final hasStartKm = startKm != null;
    final hasEndKm = endKm != null;
    final canRecordStart =
        !hasStartKm &&
        status != 'cancelled' &&
        status != 'completed' &&
        (status == 'confirmed' || status == 'pending');

    final agreement = data['agreement'];
    final isSigned = agreement is Map && agreement['isSigned'] == true;

    final canRecordEnd = hasStartKm && !hasEndKm && status != 'cancelled';

    final hasPickupVideo = data['pickupVideo'] != null;
    final hasReturnVideo = data['returnVideo'] != null;
    final canRecordPickupVideo =
        !hasPickupVideo && (status == 'confirmed' || status == 'pending');
    // 'in_progress' lives on tripStatus (set when pickup km is recorded);
    // booking status never takes that value, so checking status hid the
    // return-video button forever.
    final canRecordReturnVideo =
        hasStartKm &&
        !hasReturnVideo &&
        status != 'cancelled' &&
        tripStatus == 'in_progress';

    final finalAmount = data['final_amount'];
    final extraKmCharge = kmAllowance is Map
        ? (kmAllowance['extraKmChargeEgp'] as num?)?.toDouble()
        : null;
    final drivenKm = kmAllowance is Map
        ? (kmAllowance['drivenKm'] as num?)?.toInt()
        : null;
    final allowedKm = kmAllowance is Map
        ? (kmAllowance['allowedKm'] as num?)?.toInt()
        : null;
    final extraKm = kmAllowance is Map
        ? (kmAllowance['extraKm'] as num?)?.toInt()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: Color(0xFFFF8C00)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    carName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bookingStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusTranslated.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: bookingStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pickup.isNotEmpty)
              _row(Icons.event, context.t('pickup'), pickup),
            if (returnD.isNotEmpty)
              _row(Icons.event_available, context.t('return'), returnD),
            if (days != null)
              _row(
                Icons.timelapse,
                context.t('duration'),
                '$days ${context.t('days')}',
              ),
            if (total != null)
              _row(
                Icons.payments_outlined,
                context.t('total'),
                'EGP ${total is num ? total.toStringAsFixed(0) : total}',
              ),
            if (data['payment_method'] != null)
              _row(
                Icons.credit_card,
                context.t('paidVia'),
                data['payment_method'].toString(),
              ),
            if (pickupLoc != null)
              _row(Icons.place, context.t('from'), pickupLoc.address),
            if (dropoffLoc != null)
              _row(Icons.flag, context.t('to'), dropoffLoc.address),
            if (hasChauffeur) ...[
              _row(
                Icons.person,
                context.t('chauffeur'),
                (data['chauffeurName'] ?? '').toString(),
              ),
              if ((data['chauffeurPhone'] ?? '').toString().isNotEmpty)
                _row(
                  Icons.phone,
                  context.t('driverPhone'),
                  data['chauffeurPhone'].toString(),
                ),
            ],
            if (tripStatus.isNotEmpty)
              _row(
                Icons.route,
                context.t('trip'),
                tripStatus.replaceAll('_', ' '),
              ),
            if (hasStartKm)
              _row(Icons.speed, context.t('pickupKm'), startKm.toString()),
            if (hasEndKm)
              _row(Icons.speed, context.t('returnKm'), endKm.toString()),
            if (drivenKm != null && allowedKm != null)
              _row(
                Icons.straighten,
                context.t('distance'),
                '$drivenKm km ($allowedKm km allowed)',
              ),
            if (extraKm != null && extraKm > 0)
              _row(
                Icons.add_road,
                context.t('extraKm'),
                '$extraKm km × ${KmBillingService.extraKmRateEgp.toStringAsFixed(0)} EGP',
              ),
            if (extraKmCharge != null && extraKmCharge > 0)
              _row(
                Icons.receipt_long,
                context.t('extraKmCharge'),
                'EGP ${extraKmCharge.toStringAsFixed(0)}',
              ),
            if (finalAmount != null && hasEndKm)
              _row(
                Icons.payments,
                context.t('finalTotal'),
                'EGP ${finalAmount is num ? finalAmount.toStringAsFixed(0) : finalAmount}',
              ),
            if (extraKmCharge != null &&
                extraKmCharge > 0 &&
                data['extraKmPaymentStatus'] != null)
              _row(
                Icons.account_balance_wallet_outlined,
                context.t('extraKmStatus'),
                extraKmPaymentStatusLabel(data),
              ),
            if (isSigned)
              _row(Icons.verified, 'Rental Agreement', 'Signed & Emailed'),
            if (hasPickupVideo || hasReturnVideo) ...[
              const SizedBox(height: 8),
              const Text(
                'Condition Videos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (hasPickupVideo)
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
                                url: data['pickupVideo']['url'],
                                title: 'Pickup Condition - $carName',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (hasReturnVideo)
                    ActionChip(
                      label: const Text('Return Video'),
                      avatar: const Icon(Icons.play_circle_fill, size: 16),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoViewerScreen(
                              url: data['returnVideo']['url'],
                              title: 'Return Condition - $carName',
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pickupLoc != null)
                  OutlinedButton.icon(
                    onPressed: () =>
                        MapsLauncher.openDirections(destination: pickupLoc),
                    icon: const Icon(Icons.directions, size: 18),
                    label: Text(context.t('directions')),
                  ),
                if (canTrack)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackTripScreen(
                            bookingId: bookingId,
                            bookingData: data,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: Text(context.t('trackTrip')),
                  ),
                if (hasChauffeur &&
                    (data['chauffeurPhone'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => WhatsAppService.messageChauffeur(
                      phone: data['chauffeurPhone'].toString(),
                      carName: carName,
                      bookingId: bookingId,
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Color(0xFF25D366),
                    ),
                    label: Text(context.t('whatsapp')),
                  ),
                if (hasChauffeur &&
                    (data['chauffeurPhone'] ?? '').toString().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => MapsLauncher.callPhone(
                      data['chauffeurPhone'].toString(),
                    ),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(context.t('call')),
                  ),
                if (!isSigned && canRecordStart)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RentalAgreementScreen(
                            bookingId: bookingId,
                            bookingData: data,
                          ),
                        ),
                      );
                      if (ok == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Agreement signed!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.assignment_turned_in, size: 18),
                    label: const Text('Sign Rental Agreement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isSigned && canRecordStart)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OdometerCaptureScreen(
                            bookingId: bookingId,
                            bookingData: data,
                            mode: OdometerCaptureMode.start,
                          ),
                        ),
                      );
                      if (ok == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('pickupKmRecorded')),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(context.t('recordPickupKm')),
                  ),
                if (canRecordPickupVideo)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CarConditionCaptureScreen(
                            bookingId: bookingId,
                            mode: ConditionCaptureMode.pickup,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Condition Video (Pickup)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (canRecordEnd)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OdometerCaptureScreen(
                            bookingId: bookingId,
                            bookingData: data,
                            mode: OdometerCaptureMode.end,
                          ),
                        ),
                      );
                      if (ok == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('returnKmRecorded')),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.camera_enhance, size: 18),
                    label: Text(context.t('recordReturnKm')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (canRecordReturnVideo)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CarConditionCaptureScreen(
                            bookingId: bookingId,
                            mode: ConditionCaptureMode.returnMode,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.videocam, size: 18),
                    label: const Text('Condition Video (Return)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: () => _cancel(context),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: Text(
                      context.t('cancel'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (canReview)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewBookingScreen(
                            bookingId: bookingId,
                            bookingData: data,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text(context.t('rateCar')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/geo_location.dart';
import 'payments_server_client.dart';
import '../l10n/locale_service.dart';
import '../l10n/notification_text.dart';

class RentalDetails {
  final String carId;
  final String carName;
  final String brand;
  final double pricePerDay;
  final DateTime pickupDate;
  final DateTime returnDate;
  final int days;
  final GeoLocation? pickupLocation;
  final GeoLocation? dropoffLocation;

  /// How many cars of this model.
  final int quantity;

  /// Colours in the customer's order of preference; the server assigns
  /// cars from the first one with free cars, then the next.
  final List<String> colorPreferences;

  const RentalDetails({
    required this.carId,
    required this.carName,
    required this.brand,
    required this.pricePerDay,
    required this.pickupDate,
    required this.returnDate,
    required this.days,
    this.pickupLocation,
    this.dropoffLocation,
    this.quantity = 1,
    this.colorPreferences = const [],
  });

  double get totalAmount => pricePerDay * days * quantity;

  Map<String, dynamic> toMap() => {
    'carId': carId,
    'carName': carName,
    'brand': brand,
    'pricePerDay': pricePerDay,
    'pickupDate': pickupDate.toIso8601String(),
    'returnDate': returnDate.toIso8601String(),
    'days': days,
    'totalAmount': totalAmount,
    'quantity': quantity,
    'colorPreferences': colorPreferences,
    if (pickupLocation != null) 'pickupLocation': pickupLocation!.toMap(),
    if (dropoffLocation != null) 'dropoffLocation': dropoffLocation!.toMap(),
  };

  factory RentalDetails.fromMap(Map<String, dynamic> map) {
    return RentalDetails(
      carId: map['carId'] as String,
      carName: map['carName'] as String,
      brand: map['brand'] as String? ?? '',
      pricePerDay: (map['pricePerDay'] as num).toDouble(),
      pickupDate: DateTime.parse(map['pickupDate'] as String),
      returnDate: DateTime.parse(map['returnDate'] as String),
      days: map['days'] as int,
      pickupLocation: GeoLocation.tryParse(map['pickupLocation']),
      dropoffLocation: GeoLocation.tryParse(map['dropoffLocation']),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      colorPreferences: [
        for (final c in (map['colorPreferences'] as List? ?? const [])) '$c',
      ],
    );
  }
}

/// Free cars of one model for some dates, per colour.
class FleetAvailability {
  const FleetAvailability({required this.colors, required this.totalAvailable});

  final List<({String name, int total, int available})> colors;
  final int totalAvailable;

  /// Colours with a name (cars saved before colours have one unnamed).
  bool get hasColors => colors.any((c) => c.name.isNotEmpty);

  factory FleetAvailability.fromJson(Map<String, dynamic> json) {
    final list = json['colors'] is List ? json['colors'] as List : const [];
    return FleetAvailability(
      colors: [
        for (final c in list)
          if (c is Map)
            (
              name: c['name']?.toString() ?? '',
              total: (c['total'] as num?)?.toInt() ?? 0,
              available: (c['available'] as num?)?.toInt() ?? 0,
            ),
      ],
      totalAvailable: (json['totalAvailable'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookingService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Creates the booking through payments_server (/api/book), which checks
  /// the fleet for the dates, assigns colours by [RentalDetails.colorPreferences],
  /// prices it and writes the booking and payment record in one
  /// transaction. Returns the new booking's id. Throws [ServerException]
  /// with a message to show (e.g. "Only 1 car is free on those dates").
  ///
  /// [paymentMethod]: 'cash' | 'instapay' | 'wallet' (transfer) | 'card' |
  /// 'paymob' (with [paymobMethod] 'card' or 'wallet').
  static Future<String> completeRental({
    required RentalDetails rental,
    required String paymentMethod,
    required String signatureUrl,
    String? paymobMethod,
    String? paymentReference,
    String? payerPhone,
  }) async {
    final body = await PaymentsServerClient.post('/api/book', {
      'carId': rental.carId,
      'pickupDay': dayString(rental.pickupDate),
      'returnDay': dayString(rental.returnDate),
      'quantity': rental.quantity,
      'colorPreferences': rental.colorPreferences,
      'pickupLocation': rental.pickupLocation?.toMap(),
      'dropoffLocation': rental.dropoffLocation?.toMap(),
      'signatureUrl': signatureUrl,
      'paymentMethod': paymentMethod,
      'paymobMethod': ?paymobMethod,
      'reference': ?paymentReference,
      'payerPhone': ?payerPhone,
    });
    final id = body['bookingId']?.toString() ?? '';
    if (id.isEmpty) throw ServerException(tr('bookingNotSaved'));
    return id;
  }

  /// Free cars of [carId] per colour for the dates (both days included).
  static Future<FleetAvailability> availability({
    required String carId,
    required DateTime pickup,
    required DateTime returnDate,
  }) async {
    final body = await PaymentsServerClient.post('/api/availability', {
      'carId': carId,
      'pickupDay': dayString(pickup),
      'returnDay': dayString(returnDate),
    });
    return FleetAvailability.fromJson(body);
  }

  /// The calendar day of [date] as "YYYY-MM-DD", the format the server uses.
  static String dayString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // Admin writes. Firestore rules restrict these to admins; the screens
  // build the field maps (aliases such as carName/car_name included).

  /// Creates a booking entered by an admin.
  static Future<void> adminCreateBooking(Map<String, dynamic> fields) =>
      _firestore.collection('bookings').add(fields);

  /// Updates the given booking fields as an admin.
  static Future<void> adminUpdateBooking(
    String bookingId,
    Map<String, dynamic> fields,
  ) => _firestore.collection('bookings').doc(bookingId).update(fields);

  /// Deletes a booking (admins only; customers cancel instead).
  static Future<void> deleteBooking(String bookingId) =>
      _firestore.collection('bookings').doc(bookingId).delete();

  /// Admin decision on an InstaPay or wallet transfer the customer reported.
  ///
  /// Confirming marks the payment paid and confirms the booking; rejecting
  /// marks both rejected so the customer can pay again or contact support.
  static Future<void> verifyManualPayment({
    required String paymentId,
    required String bookingId,
    required bool approved,
  }) async {
    final booking = _firestore.collection('bookings').doc(bookingId);
    final snapshot = await booking.get();
    final data = snapshot.data();
    if (data == null) throw Exception(tr('bookingNotFound'));

    final batch = _firestore.batch();
    batch.update(_firestore.collection('payments').doc(paymentId), {
      'status': approved ? 'paid' : 'rejected',
      'verifiedAt': FieldValue.serverTimestamp(),
    });
    batch.update(booking, {
      'payment_status': approved ? 'paid' : 'rejected',
      // Only a still-pending booking is confirmed; never resurrect a
      // cancelled one.
      if (approved && data['status'] == 'pending') 'status': 'confirmed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    final userId = data['userId']?.toString() ?? '';
    if (userId.isEmpty) return;
    final car = (data['carName'] ?? data['car_name'] ?? 'car').toString();
    await _bestEffort(
      _notifyUser(
        userId: userId,
        title: approved ? 'Payment confirmed' : 'Payment not found',
        body: approved
            ? 'We received your payment. Your $car booking is confirmed.'
            : 'We could not find your transfer for the $car booking. '
                  'Please check the transaction ID or contact us.',
        type: approved ? 'payment_confirmed' : 'payment_rejected',
        bookingId: bookingId,
        i18n: approved
            ? notificationI18n('nPaymentConfirmed', 'nPaymentConfirmedBody', {
                'car': car,
              })
            : notificationI18n('nPaymentNotFound', 'nPaymentNotFoundBody', {
                'car': car,
              }),
      ),
    );
  }

  /// Loads a booking the signed-in customer owns (by uid or email), or
  /// throws the same errors every customer action reports.
  static Future<
    ({
      User user,
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, dynamic> data,
    })
  >
  _loadOwnedBooking(String bookingId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception(tr('notSignedIn'));

    final ref = _firestore.collection('bookings').doc(bookingId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception(tr('bookingNotFound'));

    final data = doc.data()!;
    if (data['userId'] != user.uid && data['user_email'] != user.email) {
      throw Exception(tr('notAllowed'));
    }
    return (user: user, ref: ref, data: data);
  }

  /// Best effort: keeps the car's current odometer in step with bookings.
  static Future<void> _updateCarOdometer(String? carId, int km) async {
    if (carId == null || carId.isEmpty) return;
    try {
      await _firestore.collection('cars').doc(carId).update({
        'current_odometer': km,
      });
    } catch (e) {
      // Best effort (a notification): never fail the main action.
      debugPrint('Best-effort write failed: $e');
    }
  }

  static Future<void> cancelBooking(String bookingId) async {
    final (:user, :ref, :data) = await _loadOwnedBooking(bookingId);

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'pending' && status != 'confirmed') {
      throw Exception(tr('onlyPendingCancel'));
    }

    final pickup = data['pickupDate'];
    if (pickup is Timestamp && pickup.toDate().isBefore(DateTime.now())) {
      throw Exception(tr('cannotCancelAfterPickup'));
    }

    await ref.update({
      'status': 'cancelled',
      'tripStatus': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    try {
      await _notifyUser(
        userId: user.uid,
        title: 'Booking cancelled',
        body:
            'Your booking for ${data['carName'] ?? data['car_name'] ?? 'car'} was cancelled.',
        type: 'booking_cancelled',
        bookingId: bookingId,
        i18n: notificationI18n('nBookingCancelled', 'nBookingCancelledBody', {
          'car': '${data['carName'] ?? data['car_name'] ?? ''}',
        }),
      );
    } catch (e) {
      // Best effort (a notification): never fail the main action.
      debugPrint('Best-effort write failed: $e');
    }
  }

  /// Tells the customer a chauffeur was assigned to their booking.
  static Future<void> notifyChauffeurAssigned({
    required String userId,
    required String bookingId,
    required String chauffeurName,
  }) => _notifyUser(
    userId: userId,
    title: 'Chauffeur assigned',
    body: '$chauffeurName will drive your trip. Track from My Bookings.',
    type: 'chauffeur_assigned',
    bookingId: bookingId,
    i18n: notificationI18n('nChauffeurAssigned', 'nChauffeurAssignedBody', {
      'name': chauffeurName,
    }),
  );

  /// Tells the customer their trip moved to [tripStatus].
  static Future<void> notifyTripStatusChanged({
    required String userId,
    required String bookingId,
    required String tripStatus,
  }) => _notifyUser(
    userId: userId,
    title: 'Trip update',
    body: 'Your trip is now ${tripStatus.replaceAll('_', ' ')}.',
    type: 'trip_$tripStatus',
    bookingId: bookingId,
    i18n: notificationI18n('nTripUpdate', 'nTripUpdateBody', {
      'tripStatus': tripStatus,
    }),
  );

  static Future<void> updateLiveLocation({
    required String bookingId,
    required double lat,
    required double lng,
  }) async {
    final bookingRef = _firestore.collection('bookings').doc(bookingId);

    final outside =
        _calculateDistance(
          lat,
          lng,
          GeoLocation.cairoLat,
          GeoLocation.cairoLng,
        ) >
        GeoLocation.geofenceRadiusKm;
    // Alert only when the car crosses out of the zone, not on every update
    // while it stays outside; `outsideGeofence` remembers the last state.
    final wasOutside =
        (await bookingRef.get()).data()?['outsideGeofence'] == true;

    await bookingRef.update({
      'liveLocation': {
        'lat': lat,
        'lng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'outsideGeofence': outside,
    });

    if (outside && !wasOutside) {
      await _notifyAdmins(
        title: 'Geofence Breach!',
        body: 'Booking $bookingId has moved outside the 100km safe zone.',
        type: 'geofence_breach',
        bookingId: bookingId,
      );
    }
  }

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = math.pi / 180;
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * Earth radius (km)
  }

  static Future<void> toggleImmobilization({
    required String bookingId,
    required bool immobilized,
  }) async {
    await _requireAdmin();
    await _firestore.collection('bookings').doc(bookingId).update({
      'security': {
        'isImmobilized': immobilized,
        'immobilizedAt': immobilized ? FieldValue.serverTimestamp() : null,
        'lastCommandBy': _auth.currentUser?.uid,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final doc = await _firestore.collection('bookings').doc(bookingId).get();
    final userId = doc.data()?['userId']?.toString();
    if (userId != null) {
      await _notifyUser(
        userId: userId,
        title: immobilized ? 'Vehicle Immobilized' : 'Vehicle Restored',
        body: immobilized
            ? 'Your vehicle has been remotely locked for security reasons. Contact support.'
            : 'Your vehicle access has been restored.',
        type: 'security_alert',
        bookingId: bookingId,
        i18n: immobilized
            ? notificationI18n('nImmobilized', 'nImmobilizedBody')
            : notificationI18n('nRestored', 'nRestoredBody'),
      );
    }
  }

  static Future<void> signRentalAgreement({
    required String bookingId,
    required String signatureUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception(tr('notSignedIn'));

    await _firestore.collection('bookings').doc(bookingId).update({
      'agreement': {
        'isSigned': true,
        'signedAt': FieldValue.serverTimestamp(),
        'signatureUrl': signatureUrl,
        'signedBy': user.uid,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Simulate sending email (in a real app, this triggers a Cloud Function)
    if (kDebugMode) debugPrint('Sending rental agreement copy to the user');
  }

  /// Runs a side write (e.g. a notification) without letting its failure
  /// fail the main action, for example if rules block the write.
  static Future<void> _bestEffort(Future<void> write) async {
    try {
      await write;
    } catch (e) {
      // Best effort (a notification): never fail the main action.
      debugPrint('Best-effort write failed: $e');
    }
  }

  static Future<void> _notifyUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? bookingId,
    Map<String, Object>? i18n,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'i18n': ?i18n,
          'type': type,
          'bookingId': ?bookingId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> _notifyAdmins({
    required String title,
    required String body,
    required String type,
    String? bookingId,
  }) async {
    // Users cannot write into other users' docs; use a shared alerts collection.
    await _firestore.collection('admin_alerts').add({
      'title': title,
      'body': body,
      'type': type,
      'bookingId': ?bookingId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> userBookingsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  static Stream<QuerySnapshot> userBookingsStreamByEmail() {
    final email = _auth.currentUser?.email;
    if (email == null) return const Stream.empty();
    return _firestore
        .collection('bookings')
        .where('user_email', isEqualTo: email)
        .snapshots();
  }

  static Future<void> recordStartKm({
    required String bookingId,
    required int km,
    required String photoUrl,
    required String photoPublicId,
  }) async {
    final (:user, :ref, :data) = await _loadOwnedBooking(bookingId);

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'cancelled' || status == 'completed') {
      throw Exception(tr('cannotRecordKm'));
    }

    final existing = data['odometer'];
    if (existing is Map && existing['startKm'] != null) {
      throw Exception(tr('pickupKmAlready'));
    }

    final carId = data['car_id']?.toString() ?? data['carId']?.toString();

    await ref.update({
      'odometer': {
        'startKm': km,
        'startPhotoUrl': photoUrl,
        'startPhotoPublicId': photoPublicId,
        'startCapturedAt': FieldValue.serverTimestamp(),
        'startCapturedBy': user.uid,
      },
      'tripStatus': 'in_progress',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _updateCarOdometer(carId, km);

    try {
      await _notifyAdmins(
        title: tr('pickupKmRecorded'),
        body:
            '${data['carName'] ?? data['car_name'] ?? 'Car'} pickup at $km km',
        type: 'odometer_start',
        bookingId: bookingId,
      );
    } catch (e) {
      // Best effort (a notification): never fail the main action.
      debugPrint('Best-effort write failed: $e');
    }
  }

  /// Records the return km and closes the rental through payments_server
  /// (/api/end-trip). The server computes the extra-km bill
  /// (the app's KmBillingService formula), completes the booking, writes the
  /// extra-km payment record and sends the notifications in one
  /// transaction. Throws [ServerException] with a message to show.
  static Future<void> recordEndKmAndFinalize({
    required String bookingId,
    required int km,
    required String photoUrl,
    required String photoPublicId,
  }) async {
    await PaymentsServerClient.post('/api/end-trip', {
      'bookingId': bookingId,
      'endKm': km,
      'photoUrl': photoUrl,
      'photoPublicId': photoPublicId,
    });
  }

  static Future<void> recordConditionVideo({
    required String bookingId,
    required String videoUrl,
    required String videoPublicId,
    required bool isPickup,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception(tr('notSignedIn'));

    final ref = _firestore.collection('bookings').doc(bookingId);
    final field = isPickup ? 'pickupVideo' : 'returnVideo';

    await ref.update({
      field: {
        'url': videoUrl,
        'publicId': videoPublicId,
        'capturedAt': FieldValue.serverTimestamp(),
        'capturedBy': user.uid,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _notifyAdmins(
        title: isPickup ? 'Pickup video uploaded' : 'Return video uploaded',
        body: 'A condition video for booking $bookingId has been uploaded.',
        type: isPickup ? 'video_pickup' : 'video_return',
        bookingId: bookingId,
      );
    } catch (e) {
      // Best effort (a notification): never fail the main action.
      debugPrint('Best-effort write failed: $e');
    }
  }

  // Condition videos are deleted 3 days after the return date by the
  // `cleanupExpiredConditionVideos` scheduled Cloud Function (functions/).

  static Future<void> _requireAdmin() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception(tr('notSignedIn'));

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.data()?['role'] != 'admin') {
      throw Exception(tr('adminRequired'));
    }
  }

  /// Admin marks extra km charge as paid or pending.
  static Future<void> setExtraKmPaymentStatus({
    required String bookingId,
    required bool paid,
  }) async {
    await _requireAdmin();

    final ref = _firestore.collection('bookings').doc(bookingId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception(tr('bookingNotFound'));

    final data = doc.data()!;
    final status = paid ? 'paid' : 'pending';
    final user = _auth.currentUser!;

    await ref.update({
      'extraKmPaymentStatus': status,
      if (paid) ...{
        'extraKmPaidAt': FieldValue.serverTimestamp(),
        'extraKmApprovedBy': user.uid,
      },
      if (!paid) ...{
        'extraKmPaidAt': FieldValue.delete(),
        'extraKmApprovedBy': FieldValue.delete(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final payments = await _firestore
        .collection('payments')
        .where('booking_id', isEqualTo: bookingId)
        .get();

    await Future.wait([
      for (final payment in payments.docs)
        if ((payment.data()['method'] ?? '').toString() == 'extra_km')
          payment.reference.update({
            'status': status,
            if (paid) 'paid_at': FieldValue.serverTimestamp(),
            if (!paid) 'paid_at': FieldValue.delete(),
          }),
    ]);

    final userId = data['userId']?.toString();
    if (userId != null && userId.isNotEmpty) {
      try {
        final km = data['kmAllowance'];
        final charge = km is Map
            ? (km['extraKmChargeEgp'] as num?)?.toDouble() ?? 0
            : 0.0;
        await _notifyUser(
          userId: userId,
          title: paid
              ? 'Extra km payment confirmed'
              : 'Extra km payment pending',
          body: paid
              ? 'Your extra km charge of EGP ${charge.toStringAsFixed(0)} is marked as paid.'
              : 'Your extra km charge of EGP ${charge.toStringAsFixed(0)} is pending payment.',
          type: paid ? 'extra_km_paid' : 'extra_km_pending',
          bookingId: bookingId,
          i18n: paid
              ? notificationI18n('nExtraKmPaid', 'nExtraKmPaidBody', {
                  'amount': charge.toStringAsFixed(0),
                })
              : notificationI18n('nExtraKmPending', 'nExtraKmPendingBody', {
                  'amount': charge.toStringAsFixed(0),
                }),
        );
      } catch (e) {
        // Best effort (a notification): never fail the main action.
        debugPrint('Best-effort write failed: $e');
      }
    }
  }
}

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/geo_location.dart';
import 'km_billing_service.dart';

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
  });

  double get totalAmount => pricePerDay * days;

  Map<String, dynamic> toMap() => {
    'carId': carId,
    'carName': carName,
    'brand': brand,
    'pricePerDay': pricePerDay,
    'pickupDate': pickupDate.toIso8601String(),
    'returnDate': returnDate.toIso8601String(),
    'days': days,
    'totalAmount': totalAmount,
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
    );
  }
}

class BookingService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<String> completeRental({
    required RentalDetails rental,
    required String paymentMethod,
    String paymentStatus = 'paid',
    String? signatureUrl,
    String? paymentReference,
    String? payerPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final userName = userData['name'] ?? user.displayName ?? 'User';
    final userEmail = user.email ?? userData['email'] ?? '';
    final userPhone = userData['phone'] ?? userData['phone_number'] ?? '';

    final status = paymentStatus == 'paid' ? 'confirmed' : 'pending';

    // Booking and payment are written atomically: a failure can no longer
    // leave a booking without its payment record (or the reverse).
    final bookingRef = _firestore.collection('bookings').doc();
    final paymentRef = _firestore.collection('payments').doc();
    final batch = _firestore.batch();
    batch.set(bookingRef, {
      'userId': user.uid,
      'user_email': userEmail,
      'userName': userName,
      'customerName': userName,
      'phone': userPhone,
      'car_id': rental.carId,
      'car_name': rental.carName,
      'carName': rental.carName,
      'brand': rental.brand,
      'pickupDate': Timestamp.fromDate(rental.pickupDate),
      'returnDate': Timestamp.fromDate(rental.returnDate),
      'startDate': Timestamp.fromDate(rental.pickupDate),
      'days': rental.days,
      'price_per_day': rental.pricePerDay,
      'total_amount': rental.totalAmount,
      'status': status,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      // paid | pending (cash) | awaiting_verification (InstaPay/wallet
      // transfer an admin must confirm) | unpaid (online checkout not done).
      'payment_status': paymentStatus,
      'payer_phone': ?payerPhone,
      'tripStatus': 'pending',
      if (rental.pickupLocation != null)
        'pickupLocation': rental.pickupLocation!.toMap(),
      if (rental.dropoffLocation != null)
        'dropoffLocation': rental.dropoffLocation!.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      if (signatureUrl != null)
        'agreement': {
          'isSigned': true,
          'signedAt': FieldValue.serverTimestamp(),
          'signatureUrl': signatureUrl,
          'signedBy': user.uid,
        },
    });

    batch.set(paymentRef, {
      'userId': user.uid,
      'user_email': userEmail,
      'booking_id': bookingRef.id,
      'car_name': rental.carName,
      'amount': rental.totalAmount,
      'method': paymentMethod,
      'reference': paymentReference,
      'payer_phone': ?payerPhone,
      'status': paymentStatus,
      'payment_date': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    // In-app notifications (never fail the payment if rules block a write).
    // Customer and admin notifications are independent: send both at once.
    await Future.wait([
      _bestEffort(
        _notifyUser(
          userId: user.uid,
          title: status == 'confirmed'
              ? 'Booking confirmed'
              : 'Booking received',
          body:
              'Your ${rental.carName} rental is $status. Open My Bookings for details.',
          type: 'booking_$status',
          bookingId: bookingRef.id,
        ),
      ),
      _bestEffort(
        _notifyAdmins(
          title: 'New booking',
          body: '$userName booked ${rental.carName}',
          type: 'new_booking',
          bookingId: bookingRef.id,
        ),
      ),
    ]);

    return bookingRef.id;
  }

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
    if (data == null) throw Exception('Booking not found');

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
    if (user == null) throw Exception('Not signed in');

    final ref = _firestore.collection('bookings').doc(bookingId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Booking not found');

    final data = doc.data()!;
    if (data['userId'] != user.uid && data['user_email'] != user.email) {
      throw Exception('Not allowed');
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
    } catch (_) {}
  }

  static Future<void> cancelBooking(String bookingId) async {
    final (:user, :ref, :data) = await _loadOwnedBooking(bookingId);

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'pending' && status != 'confirmed') {
      throw Exception('Only pending or confirmed bookings can be cancelled');
    }

    final pickup = data['pickupDate'];
    if (pickup is Timestamp && pickup.toDate().isBefore(DateTime.now())) {
      throw Exception('Cannot cancel after pickup date');
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
      );
    } catch (_) {}
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
      );
    }
  }

  static Future<void> signRentalAgreement({
    required String bookingId,
    required String signatureUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

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
    } catch (_) {}
  }

  static Future<void> _notifyUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? bookingId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
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

  static int? _odometerKm(Map<String, dynamic>? odometer, String key) {
    if (odometer == null) return null;
    final v = odometer[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
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
      throw Exception('Cannot record km for this booking');
    }

    final existing = data['odometer'];
    if (existing is Map && existing['startKm'] != null) {
      throw Exception('Pickup km already recorded');
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
        title: 'Pickup km recorded',
        body:
            '${data['carName'] ?? data['car_name'] ?? 'Car'} pickup at $km km',
        type: 'odometer_start',
        bookingId: bookingId,
      );
    } catch (_) {}
  }

  static Future<void> recordEndKmAndFinalize({
    required String bookingId,
    required int km,
    required String photoUrl,
    required String photoPublicId,
  }) async {
    final (:user, :ref, :data) = await _loadOwnedBooking(bookingId);

    final odometer = data['odometer'];
    if (odometer is! Map) {
      throw Exception('Record pickup km first');
    }

    final odometerMap = Map<String, dynamic>.from(odometer);
    final startKm = _odometerKm(odometerMap, 'startKm');
    if (startKm == null) throw Exception('Record pickup km first');
    if (odometerMap['endKm'] != null) {
      throw Exception('Return km already recorded');
    }
    if (km < startKm) {
      throw Exception('Return km must be at least $startKm');
    }

    final days = (data['days'] as num?)?.toInt() ?? 1;
    final baseAmount = (data['total_amount'] as num?)?.toDouble() ?? 0;
    final billing = KmBillingService.calculate(
      startKm: startKm,
      endKm: km,
      rentalDays: days,
    );
    final finalAmount = KmBillingService.finalAmount(
      baseAmount: baseAmount,
      billing: billing,
    );

    final carId = data['car_id']?.toString() ?? data['carId']?.toString();
    final carName = (data['carName'] ?? data['car_name'] ?? 'car').toString();

    await ref.update({
      'odometer': {
        ...Map<String, dynamic>.from(odometer),
        'endKm': km,
        'endPhotoUrl': photoUrl,
        'endPhotoPublicId': photoPublicId,
        'endCapturedAt': FieldValue.serverTimestamp(),
        'endCapturedBy': user.uid,
      },
      'kmAllowance': {
        'kmPerDay': KmBillingService.kmPerDay,
        'allowedKm': billing.allowedKm,
        'drivenKm': billing.drivenKm,
        'extraKm': billing.extraKm,
        'extraKmRateEgp': KmBillingService.extraKmRateEgp,
        'extraKmChargeEgp': billing.extraKmChargeEgp,
      },
      'final_amount': finalAmount,
      'extraKmPaymentStatus': billing.extraKm > 0
          ? 'pending'
          : 'not_applicable',
      'status': 'completed',
      'tripStatus': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _updateCarOdometer(carId, km);

    if (billing.extraKmChargeEgp > 0) {
      await _firestore.collection('payments').add({
        'userId': user.uid,
        'user_email': user.email ?? data['user_email'],
        'booking_id': bookingId,
        'car_name': carName,
        'amount': billing.extraKmChargeEgp,
        'method': 'extra_km',
        'status': 'pending',
        'description':
            'Extra ${billing.extraKm} km (${billing.drivenKm} driven, '
            '${billing.allowedKm} allowed)',
        'payment_date': FieldValue.serverTimestamp(),
      });
    }

    // Customer and admin notifications are independent: send both at once.
    await Future.wait([
      _bestEffort(
        _notifyUser(
          userId: user.uid,
          title: 'Rental completed',
          body: billing.extraKm > 0
              ? '$carName returned. Extra ${billing.extraKm} km: '
                    'EGP ${billing.extraKmChargeEgp.toStringAsFixed(0)} due.'
              : '$carName returned. No extra km charges.',
          type: 'rental_completed',
          bookingId: bookingId,
        ),
      ),
      _bestEffort(
        _notifyAdmins(
          title: 'Return km recorded',
          body:
              '$carName returned at $km km. '
              'Extra: ${billing.extraKm} km (EGP ${billing.extraKmChargeEgp.toStringAsFixed(0)})',
          type: 'odometer_end',
          bookingId: bookingId,
        ),
      ),
    ]);
  }

  static Future<void> recordConditionVideo({
    required String bookingId,
    required String videoUrl,
    required String videoPublicId,
    required bool isPickup,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

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
    } catch (_) {}
  }

  // Condition videos are deleted 3 days after the return date by the
  // `cleanupExpiredConditionVideos` scheduled Cloud Function (functions/).

  static Future<void> _requireAdmin() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.data()?['role'] != 'admin') {
      throw Exception('Admin access required');
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
    if (!doc.exists) throw Exception('Booking not found');

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
        );
      } catch (_) {}
    }
  }
}

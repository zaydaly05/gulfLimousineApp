import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../utils/booking_fields.dart';
import 'payments_server_client.dart';

class TrafficViolationService {
  TrafficViolationService._();

  static const sourceBooking = 'booking';
  static const sourceGift = 'complimentary';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get collection =>
      _db.collection('traffic_violations');

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() {
    return collection.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchForRental(
    String rentalId,
  ) {
    return collection.where('rentalId', isEqualTo: rentalId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchForUserId(
    String userId,
  ) {
    return collection.where('userId', isEqualTo: userId).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchForEmail(
    String email,
  ) {
    return collection.where('user_email', isEqualTo: email).snapshots();
  }

  static bool belongsToUser(
    Map<String, dynamic> data, {
    required String? userId,
    required String? email,
  }) {
    if (userId != null &&
        userId.isNotEmpty &&
        (data['userId'] ?? '').toString() == userId) {
      return true;
    }
    final stored = (data['user_email'] ?? '').toString().trim().toLowerCase();
    return email != null &&
        email.trim().isNotEmpty &&
        stored == email.trim().toLowerCase();
  }

  static Map<String, dynamic> customerFromRental(
    String sourceType,
    Map<String, dynamic> rental,
  ) {
    if (sourceType == sourceGift) {
      return {
        'customerName': (rental['recipientName'] ?? 'Guest').toString(),
        'user_email': (rental['email'] ?? '').toString(),
        'phone': (rental['phone'] ?? '').toString(),
        if ((rental['userId'] ?? '').toString().isNotEmpty)
          'userId': rental['userId'].toString(),
        'car_id': (rental['car_id'] ?? '').toString(),
        'car_name': resolveBookingCar(rental),
        'brand': (rental['brand'] ?? '').toString(),
      };
    }
    return {
      'customerName': resolveBookingName(rental),
      'user_email': (rental['user_email'] ?? '').toString(),
      'phone': (rental['phone'] ?? rental['phone_number'] ?? '').toString(),
      if ((rental['userId'] ?? '').toString().isNotEmpty)
        'userId': rental['userId'].toString(),
      'car_id': (rental['car_id'] ?? rental['carId'] ?? '').toString(),
      'car_name': resolveBookingCar(rental),
      'brand': (rental['brand'] ?? '').toString(),
    };
  }

  static Future<String?> _lookupUserId(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  static Future<void> add({
    required String sourceType,
    required String rentalId,
    required Map<String, dynamic> rental,
    required double amount,
    required DateTime violationDate,
    required String status,
    String ticketNumber = '',
    String description = '',
    String location = '',
  }) async {
    final customer = customerFromRental(sourceType, rental);
    final admin = FirebaseAuth.instance.currentUser;
    final email = (customer['user_email'] ?? '').toString().trim();
    var userId = (customer['userId'] ?? '').toString();
    if (userId.isEmpty && email.isNotEmpty) {
      userId = await _lookupUserId(email) ?? '';
    }
    if (userId.isNotEmpty) {
      customer['userId'] = userId;
    } else {
      customer.remove('userId');
    }

    await collection.add({
      ...customer,
      'sourceType': sourceType,
      'rentalId': rentalId,
      'amount': amount,
      'violationDate': Timestamp.fromDate(violationDate),
      'ticketNumber': ticketNumber.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'status': status,
      'charged': status != 'waived',
      'createdBy': admin?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      if (status == 'paid') 'paidAt': FieldValue.serverTimestamp(),
    });

    if (userId.isNotEmpty && status == 'pending') {
      try {
        await _db.collection('users').doc(userId).collection('notifications').add({
          'title': 'Traffic violation',
          'body':
              'A traffic ticket of EGP ${amount.toStringAsFixed(0)} was added for ${customer['car_name'] ?? 'your rental'}. Open Traffic tickets to pay.',
          'type': 'traffic_violation',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  static Future<void> setStatus(String id, String status) async {
    await collection.doc(id).update({
      'status': status,
      'charged': status != 'waived',
      if (status == 'paid') 'paidAt': FieldValue.serverTimestamp(),
      if (status != 'paid') 'paidAt': FieldValue.delete(),
    });
  }

  /// Pays the signed-in customer's own ticket through payments_server
  /// (/api/pay-ticket), which updates the ticket and writes its payment
  /// record. Cash leaves the ticket pending until an admin confirms it.
  /// Throws [ServerException] with a message to show.
  static Future<void> pay({
    required String violationId,
    required String paymentMethod,
  }) async {
    await PaymentsServerClient.post('/api/pay-ticket', {
      'violationId': violationId,
      'paymentMethod': paymentMethod,
    });
  }

  static Future<void> delete(String id) => collection.doc(id).delete();

  static final _dateFormat = DateFormat('dd MMM yyyy');

  /// The ticket's violation date as "dd MMM yyyy", or '' if it has none.
  static String violationDateLabel(Map<String, dynamic> data) {
    final date = data['violationDate'];
    return date is Timestamp ? _dateFormat.format(date.toDate()) : '';
  }

  static double amountOf(Map<String, dynamic> data) {
    return (data['amount'] as num?)?.toDouble() ?? 0;
  }

  static bool isPending(Map<String, dynamic> data) {
    return (data['status'] ?? '') == 'pending';
  }

  static double pendingTotal(Iterable<QueryDocumentSnapshot> docs) {
    return docs.fold<double>(0, (total, doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!isPending(data)) return total;
      return total + amountOf(data);
    });
  }
}

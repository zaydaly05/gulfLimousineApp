import 'package:cloud_firestore/cloud_firestore.dart';

/// Complimentary (gifted) car rentals, managed by admins.
///
/// Rule kept here in one place: a car with an active gift is hidden from the
/// public fleet (`cars.available = false`) and only becomes available again
/// once no other active gift uses it.
class ComplimentaryRentalService {
  ComplimentaryRentalService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get collection =>
      _db.collection('complimentary_rentals');

  /// Value of the gift: the stored amount, else days × daily rate.
  static double giftedValue(Map<String, dynamic> data) {
    final stored = data['gifted_value'] ?? data['total_amount'];
    if (stored is num) return stored.toDouble();
    final days = (data['days'] as num?)?.toDouble() ?? 0;
    final price = (data['price_per_day'] as num?)?.toDouble() ?? 0;
    return days * price;
  }

  /// Records a new gift and hides its car (`fields['car_id']`) from the fleet.
  static Future<void> grant(Map<String, dynamic> fields) async {
    await collection.add(fields);
    await _db.collection('cars').doc(fields['car_id'] as String).update({
      'available': false,
    });
  }

  /// Sets a gift's [status]; ending or cancelling it frees the car unless
  /// another active gift still uses it.
  static Future<void> setStatus(
    String id,
    Map<String, dynamic> data,
    String status,
  ) async {
    final carId = (data['car_id'] ?? '').toString();
    await collection.doc(id).update({
      'status': status,
      'endedAt': FieldValue.serverTimestamp(),
    });

    if (carId.isNotEmpty && (status == 'completed' || status == 'cancelled')) {
      await _releaseCarIfUnused(carId, exceptDocId: id);
    }
  }

  /// Deletes a gift record, freeing its car first if the gift was active.
  static Future<void> delete(String id, Map<String, dynamic> data) async {
    if ((data['status'] ?? '') == 'active') {
      final carId = (data['car_id'] ?? '').toString();
      if (carId.isNotEmpty) {
        await _releaseCarIfUnused(carId, exceptDocId: id);
      }
    }
    await collection.doc(id).delete();
  }

  static Future<void> _releaseCarIfUnused(
    String carId, {
    required String exceptDocId,
  }) async {
    final others = await collection.where('car_id', isEqualTo: carId).get();

    final stillOut = others.docs.any((doc) {
      if (doc.id == exceptDocId) return false;
      return (doc.data()['status'] ?? '') == 'active';
    });

    if (!stillOut) {
      await _db.collection('cars').doc(carId).update({'available': true});
    }
  }
}

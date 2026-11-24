import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/content_labels.dart';
import '../l10n/locale_service.dart';

/// Reads and toggles the signed-in user's favorite cars.
class FavoritesService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>>? get _ref {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('favorites');
  }

  /// Favorite car documents of the signed-in user, or null when signed out.
  static Stream<QuerySnapshot<Map<String, dynamic>>>? watchFavorites() =>
      _ref?.snapshots();

  static Stream<Set<String>> watchFavoriteIds() {
    final ref = _ref;
    if (ref == null) return Stream.value({});
    return ref.snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }

  static Future<void> toggle(String carId, Map<String, dynamic> car) async {
    final ref = _ref;
    if (ref == null) return;
    final doc = ref.doc(carId);
    final exists = await doc.get();
    if (exists.exists) {
      await doc.delete();
    } else {
      await doc.set({
        'carId': carId,
        'name': car['name'],
        'brand': car['brand'],
        'image_url': car['imageUrl'] ?? car['image_url'],
        'price_per_day': car['pricePerDay'] ?? car['price_per_day'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// The car as it is now in `cars/{carId}`, in the shape the car list and
  /// rent sheet use, or null when it was deleted or switched off.
  ///
  /// A favourite stores the price and name from when it was saved, so the
  /// rent sheet must not book from it: an admin may have changed the price.
  static Future<Map<String, dynamic>?> liveCar(String carId) async {
    final doc = await _firestore.collection('cars').doc(carId).get();
    final data = doc.data();
    if (data == null || data['available'] == false) return null;
    final price = data['price_per_day'];
    return {
      ...data,
      'id': doc.id,
      'name': carNameOf(data, fallback: tr('carFallback')),
      'brand': (data['brand'] ?? '').toString(),
      'pricePerDay': price is num
          ? price.toDouble()
          : double.tryParse(price?.toString() ?? '') ?? 0,
      'imageUrl': data['image_url'],
      'available': true,
    };
  }
}

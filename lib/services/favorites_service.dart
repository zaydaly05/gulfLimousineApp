import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  static Future<bool> isFavorite(String carId) async {
    final ref = _ref;
    if (ref == null) return false;
    return (await ref.doc(carId).get()).exists;
  }
}

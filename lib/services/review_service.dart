import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Customer reviews of completed bookings and the per-car rating summary.
class ReviewService {
  ReviewService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Saves a review, marks the booking as reviewed and refreshes the car's
  /// `avgRating` / `reviewCount`.
  static Future<void> submitReview({
    required String bookingId,
    required Map<String, dynamic> booking,
    required int rating,
    required String comment,
  }) async {
    final carId = (booking['car_id'] ?? booking['carId'] ?? '').toString();
    final carName = (booking['carName'] ?? booking['car_name'] ?? 'Car')
        .toString();

    // The booking id is the document id: one review per booking (enforced
    // by firestore.rules).
    await _db.collection('reviews').doc(bookingId).set({
      'bookingId': bookingId,
      'carId': carId,
      'carName': carName,
      'rating': rating,
      'comment': comment.trim(),
      // The reviewer: bookings an admin entered have no userId of their own.
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'userName': booking['userName'] ?? booking['customerName'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('bookings').doc(bookingId).update({
      'reviewed': true,
      'rating': rating,
    });

    if (carId.isNotEmpty) await _refreshCarRating(carId, fallback: rating);
  }

  static Future<void> _refreshCarRating(
    String carId, {
    required int fallback,
  }) async {
    final reviews = await _db
        .collection('reviews')
        .where('carId', isEqualTo: carId)
        .get();
    final ratings = [for (final doc in reviews.docs) doc.data()['rating']];
    await _db.collection('cars').doc(carId).set({
      'avgRating': averageRating(ratings, fallback: fallback.toDouble()),
      'reviewCount': reviews.docs.length,
    }, SetOptions(merge: true));
  }

  /// Mean of [ratings] (non-numbers count as 0), or [fallback] when empty.
  @visibleForTesting
  static double averageRating(
    List<dynamic> ratings, {
    required double fallback,
  }) {
    if (ratings.isEmpty) return fallback;
    final sum = ratings.fold<double>(
      0,
      (total, r) => total + ((r as num?)?.toDouble() ?? 0),
    );
    return sum / ratings.length;
  }
}

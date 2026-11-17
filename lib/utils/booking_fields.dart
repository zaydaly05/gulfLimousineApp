// Field access for booking documents. Bookings were written by several
// versions of the app, so most fields have aliases (carName / car_name,
// userName / customerName, startDate / pickupDate); these helpers are the
// one place that knows the lookup order. Pure Dart: no widgets, so services
// can use them too.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../l10n/locale_service.dart';

/// Converts a Firestore date field (Timestamp, DateTime or ISO string).
DateTime? parseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

final _bookingDateFormat = DateFormat('dd MMM yyyy');

String formatBookingDate(dynamic value) {
  final date = parseFirestoreDate(value);
  if (date == null) {
    if (value != null && value.toString().isNotEmpty) return value.toString();
    return '';
  }
  return _bookingDateFormat.format(date);
}

String resolveBookingName(Map<String, dynamic> data) {
  return data['userName'] ??
      data['customerName'] ??
      data['user_email'] ??
      tr('unknown');
}

String resolveBookingCar(Map<String, dynamic> data) {
  return data['carName'] ?? data['car_name'] ?? tr('carFallback');
}

String resolveBookingDateLabel(Map<String, dynamic> data) {
  return formatBookingDate(
    data['startDate'] ?? data['pickupDate'] ?? data['createdAt'],
  );
}

Map<String, dynamic>? parseKmAllowance(Map<String, dynamic> booking) {
  final km = booking['kmAllowance'];
  if (km is Map) return Map<String, dynamic>.from(km);
  return null;
}

Map<String, dynamic>? parseOdometer(Map<String, dynamic> booking) {
  final odometer = booking['odometer'];
  if (odometer is Map) return Map<String, dynamic>.from(odometer);
  return null;
}

bool bookingHasExtraKmCharge(Map<String, dynamic> booking) {
  final km = parseKmAllowance(booking);
  final charge = (km?['extraKmChargeEgp'] as num?)?.toDouble() ?? 0;
  return charge > 0;
}

String extraKmPaymentStatusLabel(Map<String, dynamic> booking) {
  final status = (booking['extraKmPaymentStatus'] ?? '').toString();
  switch (status) {
    case 'paid':
      return tr('paidLabel');
    case 'pending':
      return tr('pendingPayment');
    case 'not_applicable':
      return tr('noExtraKm');
    default:
      return status.isEmpty ? 'N/A' : status;
  }
}

ExtraKmDashboardStats computeExtraKmStats(
  List<QueryDocumentSnapshot> bookings,
) {
  var pendingCount = 0;
  var pendingAmount = 0.0;
  var paidAmount = 0.0;

  for (final doc in bookings) {
    final data = doc.data() as Map<String, dynamic>;
    if (!bookingHasExtraKmCharge(data)) continue;

    final km = parseKmAllowance(data)!;
    final charge = (km['extraKmChargeEgp'] as num?)?.toDouble() ?? 0;
    final status = (data['extraKmPaymentStatus'] ?? '').toString();

    if (status == 'paid') {
      paidAmount += charge;
    } else if (status == 'pending') {
      pendingCount++;
      pendingAmount += charge;
    }
  }

  return ExtraKmDashboardStats(
    pendingCount: pendingCount,
    pendingAmount: pendingAmount,
    paidAmount: paidAmount,
  );
}

class ExtraKmDashboardStats {
  final int pendingCount;
  final double pendingAmount;
  final double paidAmount;

  const ExtraKmDashboardStats({
    required this.pendingCount,
    required this.pendingAmount,
    required this.paidAmount,
  });
}

/// Like [parseFirestoreDate] but ignores strings: only Timestamp/DateTime.
DateTime? timestampDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Newest `createdAt` first; documents without a Timestamp keep their
/// relative position (compare as equal).
int compareCreatedAtDesc(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
  final aDate = (a.data() as Map<String, dynamic>)['createdAt'];
  final bDate = (b.data() as Map<String, dynamic>)['createdAt'];
  if (aDate is Timestamp && bDate is Timestamp) {
    return bDate.compareTo(aDate);
  }
  return 0;
}

/// A sorted copy of [docs], newest `createdAt` first.
List<T> sortedByCreatedAtDesc<T extends QueryDocumentSnapshot>(
  Iterable<T> docs,
) => List<T>.from(docs)..sort(compareCreatedAtDesc);

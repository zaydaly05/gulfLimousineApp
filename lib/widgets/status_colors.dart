import 'package:flutter/material.dart';

/// Badge colour for a booking `status` (confirmed/paid/completed, cancelled,
/// anything else is treated as pending).
Color bookingStatusColor(String status) {
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

/// Badge colour for a traffic violation `status`.
Color violationStatusColor(String status) {
  switch (status) {
    case 'paid':
      return Colors.green;
    case 'waived':
      return Colors.grey;
    default:
      return Colors.orange;
  }
}

Color extraKmPaymentStatusColor(Map<String, dynamic> booking) {
  final status = (booking['extraKmPaymentStatus'] ?? '').toString();
  switch (status) {
    case 'paid':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

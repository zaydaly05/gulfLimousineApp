import 'package:flutter/material.dart';

import '../services/booking_service.dart';
import '../services/km_billing_service.dart';
import 'admin_charts.dart';
import 'status_pill.dart';
import 'action_button_row.dart';
import '../l10n/locale_service.dart';

class ExtraKmAdminPanel extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> booking;
  final bool compact;

  const ExtraKmAdminPanel({
    super.key,
    required this.bookingId,
    required this.booking,
    this.compact = false,
  });

  @override
  State<ExtraKmAdminPanel> createState() => _ExtraKmAdminPanelState();
}

class _ExtraKmAdminPanelState extends State<ExtraKmAdminPanel> {
  bool _loading = false;

  Map<String, dynamic> get _booking => widget.booking;

  Future<void> _setPaid(bool paid) async {
    final label = paid ? 'paid' : 'pending';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          paid ? tr('confirmPaymentReceivedQ') : tr('markUnpaidQ'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          paid ? tr('markExtraKmPaid') : tr('setExtraKmPending'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              paid ? tr('markPaid') : tr('markPending'),
              style: TextStyle(color: paid ? Colors.green : Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await BookingService.setExtraKmPaymentStatus(
        bookingId: widget.bookingId,
        paid: paid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('extraKmMarkedAs', args: {'label': label})),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final odometer = parseOdometer(_booking);
    final km = parseKmAllowance(_booking);
    final startKm = odometer?['startKm'];
    final endKm = odometer?['endKm'];
    final hasKmData = startKm != null || endKm != null;
    final hasExtra = bookingHasExtraKmCharge(_booking);
    final paymentStatus = (_booking['extraKmPaymentStatus'] ?? '').toString();
    final isPending = paymentStatus == 'pending';
    final isPaid = paymentStatus == 'paid';
    final finalAmount = (_booking['final_amount'] as num?)?.toDouble();
    final baseAmount = (_booking['total_amount'] as num?)?.toDouble() ?? 0;

    if (!hasKmData && !hasExtra) {
      return Text(
        tr('noOdometerReadingsYet'),
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('odometerExtraKm'),
                style: TextStyle(
                  color: Colors.grey.shade200,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (startKm != null) _line(tr('pickupKm'), startKm.toString()),
          if (endKm != null) _line(tr('returnKm'), endKm.toString()),
          if (km != null) ...[
            if (km['drivenKm'] != null)
              _line(
                tr('driven'),
                tr('kmValue', args: {'n': '${km['drivenKm']}'}),
              ),
            if (km['allowedKm'] != null)
              _line(
                tr('allowed'),
                tr('kmValue', args: {'n': '${km['allowedKm']}'}),
              ),
            if ((km['extraKm'] as num? ?? 0) > 0)
              _line(
                tr('extraKm'),
                tr(
                  'extraKmRate',
                  args: {
                    'km': '${km['extraKm']}',
                    'rate': KmBillingService.extraKmRateEgp.toStringAsFixed(0),
                  },
                ),
              ),
            if ((km['extraKmChargeEgp'] as num? ?? 0) > 0)
              _line(
                tr('extraCharge'),
                egp(km['extraKmChargeEgp'] as num),
                highlight: true,
              ),
          ],
          if (finalAmount != null && endKm != null)
            _line(
              tr('finalTotal'),
              tr(
                'finalWithBase',
                args: {'total': egp(finalAmount), 'base': egp(baseAmount)},
              ),
            ),
          if (hasExtra) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  tr('payment2'),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                StatusPill(
                  label: extraKmPaymentStatusLabel(_booking).toUpperCase(),
                  color: extraKmPaymentStatusColor(_booking),
                ),
              ],
            ),
          ],
          if (hasExtra && (isPending || isPaid)) ...[
            const SizedBox(height: 10),
            if (_loading)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (widget.compact)
              ActionButtonRow(
                children: [
                  if (isPending)
                    ElevatedButton.icon(
                      onPressed: () => _setPaid(true),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: Text(tr('markPaid')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (isPaid)
                    OutlinedButton.icon(
                      onPressed: () => _setPaid(false),
                      icon: const Icon(Icons.undo, size: 18),
                      label: Text(tr('markPending')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isPending)
                    ElevatedButton.icon(
                      onPressed: () => _setPaid(true),
                      icon: const Icon(Icons.check_circle),
                      label: Text(tr('approveExtraKmPaid')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  if (isPaid) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _setPaid(false),
                      icon: const Icon(Icons.undo),
                      label: Text(tr('markAsUnpaid')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? Colors.orange : Colors.grey.shade300,
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

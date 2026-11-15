import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/traffic_violation_service.dart';
import '../utils/booking_fields.dart';
import 'status_colors.dart';

class TrafficViolationsAdminPanel extends StatefulWidget {
  final String sourceType;
  final String rentalId;
  final Map<String, dynamic> rentalData;
  final bool compact;

  const TrafficViolationsAdminPanel({
    super.key,
    required this.sourceType,
    required this.rentalId,
    required this.rentalData,
    this.compact = false,
  });

  static Future<void> openAddDialog({
    required BuildContext context,
    required String sourceType,
    required String rentalId,
    required Map<String, dynamic> rentalData,
  }) {
    return showDialog(
      context: context,
      builder: (_) => _AddTrafficViolationDialog(
        sourceType: sourceType,
        rentalId: rentalId,
        rentalData: rentalData,
      ),
    );
  }

  @override
  State<TrafficViolationsAdminPanel> createState() =>
      _TrafficViolationsAdminPanelState();
}

class _TrafficViolationsAdminPanelState
    extends State<TrafficViolationsAdminPanel> {
  // One listener per panel, kept across rebuilds of the list it sits in;
  // re-created only if the panel is reused for another rental.
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      TrafficViolationService.watchForRental(widget.rentalId);

  @override
  void didUpdateWidget(TrafficViolationsAdminPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rentalId != widget.rentalId) {
      _stream = TrafficViolationService.watchForRental(widget.rentalId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data?.docs ?? [],
                )
                .where(
                  (doc) =>
                      (doc.data()['sourceType'] ?? '') == widget.sourceType,
                )
                .toList();
        docs.sort(compareCreatedAtDesc);
        final pending = TrafficViolationService.pendingTotal(docs);

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
                  const Icon(Icons.gavel, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Traffic violations',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => TrafficViolationsAdminPanel.openAddDialog(
                      context: context,
                      sourceType: widget.sourceType,
                      rentalId: widget.rentalId,
                      rentalData: widget.rentalData,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (docs.isEmpty)
                Text(
                  'No violations recorded for this rental',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                )
              else ...[
                Text(
                  pending > 0
                      ? '${docs.length} recorded · EGP ${pending.toStringAsFixed(0)} pending'
                      : '${docs.length} recorded · none pending',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                if (!widget.compact) ...[
                  const SizedBox(height: 8),
                  ...docs.map((doc) {
                    final data = doc.data();
                    final status = (data['status'] ?? 'pending').toString();
                    final dateLabel =
                        TrafficViolationService.violationDateLabel(data);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              [
                                'EGP ${TrafficViolationService.amountOf(data).toStringAsFixed(0)}',
                                if ((data['ticketNumber'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  '#${data['ticketNumber']}',
                                if (dateLabel.isNotEmpty) dateLabel,
                              ].join(' · '),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: violationStatusColor(status)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: violationStatusColor(status),
                              ),
                            ),
                          ),
                          if (status == 'pending')
                            IconButton(
                              tooltip: 'Mark paid',
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 20,
                              ),
                              onPressed: () =>
                                  TrafficViolationService.setStatus(
                                    doc.id,
                                    'paid',
                                  ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AddTrafficViolationDialog extends StatefulWidget {
  final String sourceType;
  final String rentalId;
  final Map<String, dynamic> rentalData;

  const _AddTrafficViolationDialog({
    required this.sourceType,
    required this.rentalId,
    required this.rentalData,
  });

  @override
  State<_AddTrafficViolationDialog> createState() =>
      _AddTrafficViolationDialogState();
}

class _AddTrafficViolationDialogState
    extends State<_AddTrafficViolationDialog> {
  final _formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final ticket = TextEditingController();
  final description = TextEditingController();
  final location = TextEditingController();
  DateTime violationDate = DateTime.now();
  String status = 'pending';
  bool _saving = false;

  @override
  void dispose() {
    amount.dispose();
    ticket.dispose();
    description.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await TrafficViolationService.add(
        sourceType: widget.sourceType,
        rentalId: widget.rentalId,
        rental: widget.rentalData,
        amount: double.parse(amount.text.trim()),
        violationDate: violationDate,
        status: status,
        ticketNumber: ticket.text,
        description: description.text,
        location: location.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Traffic violation saved (admin only)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text(
        'Add traffic violation',
        style: TextStyle(color: Colors.white),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount (EGP)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              TextFormField(
                controller: ticket,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Ticket / receipt no. (optional)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextFormField(
                controller: description,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Violation type / note',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              TextFormField(
                controller: location,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: status,
                dropdownColor: Colors.grey.shade900,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Payment status',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'waived', child: Text('Waived')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => status = v);
                },
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDate: violationDate,
                  );
                  if (picked != null) {
                    setState(() => violationDate = picked);
                  }
                },
                child: Text(
                  'Date: ${DateFormat('dd MMM yyyy').format(violationDate)}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

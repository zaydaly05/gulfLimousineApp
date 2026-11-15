import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/traffic_violation_service.dart';
import '../widgets/admin_charts.dart';
import '../widgets/traffic_violations_admin_panel.dart';

import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/live_refresh.dart';

class TrafficViolationsScreen extends StatefulWidget {
  const TrafficViolationsScreen({super.key});

  @override
  State<TrafficViolationsScreen> createState() =>
      _TrafficViolationsScreenState();
}

class _TrafficViolationsScreenState extends State<TrafficViolationsScreen> {
  // Created once, not in build(): rebuilding it on every setState would
  // reopen the Firestore listener and flash the loading spinner.
  final _violationsStream = TrafficViolationService.watchAll();
  String _status = 'all';
  String _source = 'all';
  String _personQuery = '';

  Future<void> _addFromPicker() async {
    final picked = await showModalBottomSheet<_PickedRental>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      builder: (_) => const _PickRentalSheet(),
    );
    if (picked == null || !mounted) return;
    await TrafficViolationsAdminPanel.openAddDialog(
      context: context,
      sourceType: picked.sourceType,
      rentalId: picked.rentalId,
      rentalData: picked.rentalData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(context.t('trafficViolationsTitle')),
        actions: const [LanguageToggleButton(dark: true), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add violation',
          style: TextStyle(color: Colors.white),
        ),
        onPressed: _addFromPicker,
      ),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _violationsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load traffic violations',
                  style: TextStyle(color: Colors.red.shade300),
                ),
              );
            }

            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data?.docs ?? [],
            );
            docs.sort(compareCreatedAtDesc);

            final pendingTotal = TrafficViolationService.pendingTotal(docs);
            final paidTotal = docs.fold<double>(0, (total, doc) {
              final data = doc.data();
              if ((data['status'] ?? '') != 'paid') return total;
              return total + TrafficViolationService.amountOf(data);
            });

            final query = _personQuery.trim().toLowerCase();
            final visible = docs.where((doc) {
              final data = doc.data();
              if (_status != 'all' && (data['status'] ?? '') != _status) {
                return false;
              }
              if (_source != 'all' && (data['sourceType'] ?? '') != _source) {
                return false;
              }
              if (query.isEmpty) return true;
              final haystack = [
                data['customerName'],
                data['user_email'],
                data['phone'],
                data['car_name'],
                data['ticketNumber'],
              ].join(' ').toLowerCase();
              return haystack.contains(query);
            }).toList();

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 88 + bottomPad),
              itemCount: visible.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin only. Customers never see these charges.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _totalTile(
                                'Pending',
                                'EGP ${pendingTotal.toStringAsFixed(0)}',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _totalTile(
                                'Collected',
                                'EGP ${paidTotal.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search customer, phone, car, ticket',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.orange,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.grey.shade700,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.orange,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (v) => setState(() => _personQuery = v),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('All status', 'all', _status, (v) {
                              setState(() => _status = v);
                            }),
                            _chip('Pending', 'pending', _status, (v) {
                              setState(() => _status = v);
                            }),
                            _chip('Paid', 'paid', _status, (v) {
                              setState(() => _status = v);
                            }),
                            _chip('Waived', 'waived', _status, (v) {
                              setState(() => _status = v);
                            }),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('All rentals', 'all', _source, (v) {
                              setState(() => _source = v);
                            }),
                            _chip(
                              'Paid rentals',
                              TrafficViolationService.sourceBooking,
                              _source,
                              (v) {
                                setState(() => _source = v);
                              },
                            ),
                            _chip(
                              'Gift cars',
                              TrafficViolationService.sourceGift,
                              _source,
                              (v) {
                                setState(() => _source = v);
                              },
                            ),
                          ],
                        ),
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(
                                'No traffic violations match these filters.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                final doc = visible[index - 1];
                final data = doc.data();
                final status = (data['status'] ?? 'pending').toString();
                final dateLabel = TrafficViolationService.violationDateLabel(
                  data,
                );
                final isGift =
                    (data['sourceType'] ?? '') ==
                    TrafficViolationService.sourceGift;

                return Card(
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isGift
                                  ? Icons.card_giftcard
                                  : Icons.directions_car,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['customerName']?.toString() ?? 'Customer',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: violationStatusColor(status)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: violationStatusColor(status),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'EGP ${TrafficViolationService.amountOf(data).toStringAsFixed(0)}'
                          '${dateLabel.isEmpty ? '' : ' · $dateLabel'}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${isGift ? 'Gift car' : 'Rental'} · ${data['car_name'] ?? 'Car'}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        if ((data['phone'] ?? '').toString().isNotEmpty)
                          Text(
                            'Phone: ${data['phone']}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if ((data['ticketNumber'] ?? '').toString().isNotEmpty)
                          Text(
                            'Ticket: ${data['ticketNumber']}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if ((data['description'] ?? '').toString().isNotEmpty)
                          Text(
                            '${data['description']}',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (status != 'paid')
                              TextButton(
                                onPressed: () =>
                                    TrafficViolationService.setStatus(
                                      doc.id,
                                      'paid',
                                    ),
                                child: const Text('Mark paid'),
                              ),
                            if (status == 'pending')
                              TextButton(
                                onPressed: () =>
                                    TrafficViolationService.setStatus(
                                      doc.id,
                                      'waived',
                                    ),
                                child: const Text('Waive'),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  TrafficViolationService.delete(doc.id),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _chip(
    String label,
    String value,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    final isOn = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: isOn,
      selectedColor: Colors.orange,
      backgroundColor: Colors.grey.shade900,
      labelStyle: TextStyle(
        color: isOn ? Colors.black : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: isOn ? Colors.orange : Colors.grey.shade700),
      onSelected: (_) => onSelected(value),
    );
  }

  Widget _totalTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedRental {
  final String sourceType;
  final String rentalId;
  final Map<String, dynamic> rentalData;

  const _PickedRental({
    required this.sourceType,
    required this.rentalId,
    required this.rentalData,
  });
}

class _PickRentalSheet extends StatefulWidget {
  const _PickRentalSheet();

  @override
  State<_PickRentalSheet> createState() => _PickRentalSheetState();
}

class _PickRentalSheetState extends State<_PickRentalSheet> {
  String sourceType = TrafficViolationService.sourceBooking;
  String? rentalId;
  Map<String, dynamic>? rentalData;

  // Re-created only when the rental type changes, not when a rental is picked.
  late Stream<QuerySnapshot> _rentalsStream = _rentalsFor(sourceType);

  static Stream<QuerySnapshot> _rentalsFor(String sourceType) =>
      FirebaseFirestore.instance
          .collection(
            sourceType == TrafficViolationService.sourceGift
                ? 'complimentary_rentals'
                : 'bookings',
          )
          .snapshots();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Which rental is this violation for?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: sourceType,
            dropdownColor: Colors.grey.shade900,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Type',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            items: const [
              DropdownMenuItem(
                value: TrafficViolationService.sourceBooking,
                child: Text('Paid rental'),
              ),
              DropdownMenuItem(
                value: TrafficViolationService.sourceGift,
                child: Text('Gift / complimentary'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                sourceType = v;
                _rentalsStream = _rentalsFor(v);
                rentalId = null;
                rentalData = null;
              });
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _rentalsStream,
            builder: (context, snapshot) {
              final docs = List<QueryDocumentSnapshot>.from(
                snapshot.data?.docs ?? [],
              );
              docs.sort(compareCreatedAtDesc);
              final limited = docs.take(80).toList();
              if (limited.isEmpty) {
                return const Text(
                  'No rentals found for this type.',
                  style: TextStyle(color: Colors.white70),
                );
              }
              return DropdownButtonFormField<String>(
                key: ValueKey(sourceType),
                initialValue: rentalId,
                dropdownColor: Colors.grey.shade900,
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Customer / car',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                items: limited.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = sourceType == TrafficViolationService.sourceGift
                      ? (data['recipientName'] ?? 'Guest').toString()
                      : resolveBookingName(data);
                  final car = resolveBookingCar(data);
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(
                      '$name · $car',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final doc = limited.firstWhere((d) => d.id == id);
                  setState(() {
                    rentalId = id;
                    rentalData = doc.data() as Map<String, dynamic>;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: rentalId == null || rentalData == null
                ? null
                : () {
                    Navigator.pop(
                      context,
                      _PickedRental(
                        sourceType: sourceType,
                        rentalId: rentalId!,
                        rentalData: rentalData!,
                      ),
                    );
                  },
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

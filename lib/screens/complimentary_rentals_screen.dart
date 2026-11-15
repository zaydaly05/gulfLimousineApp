import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/traffic_violations_admin_panel.dart';
import '../services/traffic_violation_service.dart';

import '../l10n/locale_service.dart';
import '../widgets/language_picker.dart';
import '../utils/rental_dates.dart';
import '../utils/booking_fields.dart';
import '../utils/live_refresh.dart';
import '../widgets/dark_form_fields.dart';

class ComplimentaryRentalsScreen extends StatefulWidget {
  const ComplimentaryRentalsScreen({super.key});

  @override
  State<ComplimentaryRentalsScreen> createState() =>
      _ComplimentaryRentalsScreenState();
}

class _ComplimentaryRentalsScreenState
    extends State<ComplimentaryRentalsScreen> {
  String? _selectedPersonKey;
  String _period = 'all';

  bool _inSelectedPeriod(DateTime? date) {
    if (_period == 'all') return true;
    if (date == null) return false;
    final now = DateTime.now();
    if (date.year != now.year) return false;
    if (_period == 'month') return date.month == now.month;
    return true;
  }

  Color _statusColor(String status, {required bool overdue}) {
    if (overdue) return Colors.red;
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  bool _isOverdue(Map<String, dynamic> data) {
    if ((data['status'] ?? '') != 'active') return false;
    final end = timestampDate(data['endDate']);
    if (end == null) return false;
    final today = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.isBefore(todayDay);
  }

  String _fmt(dynamic value) {
    final date = timestampDate(value);
    if (date == null) return '';
    return DateFormat('dd MMM yyyy').format(date);
  }

  DateTime? _giftDate(Map<String, dynamic> data) {
    return timestampDate(data['startDate']) ?? timestampDate(data['createdAt']);
  }

  double _giftedValue(Map<String, dynamic> data) {
    final stored = data['gifted_value'] ?? data['total_amount'];
    if (stored is num) return stored.toDouble();
    final days = (data['days'] as num?)?.toDouble() ?? 0;
    final price = (data['price_per_day'] as num?)?.toDouble() ?? 0;
    return days * price;
  }

  bool _countsTowardGiftTotal(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    return status != 'cancelled';
  }

  String _egp(num value) => 'EGP ${value.toStringAsFixed(0)}';

  String _personKey(Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final phone = (data['phone'] ?? '').toString().trim();
    final name = (data['recipientName'] ?? 'Guest')
        .toString()
        .trim()
        .toLowerCase();
    if (phone.isNotEmpty) return 'p:$phone';
    if (email.isNotEmpty) return 'e:$email';
    return 'n:$name';
  }

  Future<void> _setStatus(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
    String status,
  ) async {
    final carId = (data['car_id'] ?? '').toString();
    await FirebaseFirestore.instance
        .collection('complimentary_rentals')
        .doc(id)
        .update({'status': status, 'endedAt': FieldValue.serverTimestamp()});

    if (carId.isNotEmpty && (status == 'completed' || status == 'cancelled')) {
      await _releaseCarIfUnused(carId, exceptDocId: id);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'completed'
              ? 'Complimentary rental ended. Car is available again.'
              : 'Complimentary rental cancelled.',
        ),
      ),
    );
  }

  Future<void> _releaseCarIfUnused(
    String carId, {
    required String exceptDocId,
  }) async {
    final others = await FirebaseFirestore.instance
        .collection('complimentary_rentals')
        .where('car_id', isEqualTo: carId)
        .get();

    final stillOut = others.docs.any((doc) {
      if (doc.id == exceptDocId) return false;
      return (doc.data()['status'] ?? '') == 'active';
    });

    if (!stillOut) {
      await FirebaseFirestore.instance.collection('cars').doc(carId).update({
        'available': true,
      });
    }
  }

  Future<void> _delete(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete record',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Remove this complimentary rental from the list?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if ((data['status'] ?? '') == 'active') {
      final carId = (data['car_id'] ?? '').toString();
      if (carId.isNotEmpty) {
        await _releaseCarIfUnused(carId, exceptDocId: id);
      }
    }

    await FirebaseFirestore.instance
        .collection('complimentary_rentals')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(context.t('complimentaryTitle')),
        actions: const [LanguageToggleButton(dark: true), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.card_giftcard, color: Colors.white),
        label: const Text('Grant car', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddComplimentaryRentalScreen(),
            ),
          );
        },
      ),
      body: RefreshIndicator(
        onRefresh: liveDataRefresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('complimentary_rentals')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load complimentary rentals',
                  style: TextStyle(color: Colors.red.shade300),
                ),
              );
            }

            final docs = List<QueryDocumentSnapshot>.from(
              snapshot.data?.docs ?? [],
            );
            docs.sort(compareCreatedAtDesc);

            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No complimentary or gift cars yet.\nTap Grant car to lend a vehicle at no charge.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            final now = DateTime.now();
            final byPerson = <String, _GiftPersonTotal>{};

            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final key = _personKey(data);
              final person = byPerson.putIfAbsent(
                key,
                () => _GiftPersonTotal(
                  key: key,
                  name: (data['recipientName'] ?? 'Guest').toString(),
                  phone: (data['phone'] ?? '').toString(),
                  email: (data['email'] ?? '').toString(),
                ),
              );
              if (!_countsTowardGiftTotal(data)) continue;
              final value = _giftedValue(data);
              final date = _giftDate(data);
              person.allCount += 1;
              person.allTotal += value;
              if (date != null && date.year == now.year) {
                person.yearCount += 1;
                person.yearTotal += value;
                if (date.month == now.month) {
                  person.monthCount += 1;
                  person.monthTotal += value;
                }
              }
            }

            final people = byPerson.values.toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

            final selectedPerson = _selectedPersonKey == null
                ? null
                : byPerson[_selectedPersonKey];
            final selectedKey = selectedPerson == null
                ? null
                : _selectedPersonKey;
            final monthTotal =
                selectedPerson?.monthTotal ??
                people.fold<double>(0, (total, p) => total + p.monthTotal);
            final yearTotal =
                selectedPerson?.yearTotal ??
                people.fold<double>(0, (total, p) => total + p.yearTotal);
            final allTotal =
                selectedPerson?.allTotal ??
                people.fold<double>(0, (total, p) => total + p.allTotal);

            final visibleDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (selectedKey != null && _personKey(data) != selectedKey) {
                return false;
              }
              return _inSelectedPeriod(_giftDate(data));
            }).toList();

            final filteredTotal = visibleDocs.fold<double>(0, (total, doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (!_countsTowardGiftTotal(data)) return total;
              return total + _giftedValue(data);
            });

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 88 + bottomPad),
              itemCount: visibleDocs.isEmpty ? 1 : visibleDocs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _GiftTotalsHeader(
                    monthTotal: monthTotal,
                    yearTotal: yearTotal,
                    allTotal: allTotal,
                    filteredTotal: filteredTotal,
                    grantCount: visibleDocs
                        .where(
                          (doc) => _countsTowardGiftTotal(
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .length,
                    people: people,
                    selectedPersonKey: selectedKey,
                    period: _period,
                    emptyFilter: visibleDocs.isEmpty,
                    format: _egp,
                    onPersonChanged: (key) =>
                        setState(() => _selectedPersonKey = key),
                    onPeriodChanged: (period) =>
                        setState(() => _period = period),
                  );
                }

                final doc = visibleDocs[index - 1];
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? 'active').toString();
                final overdue = _isOverdue(data);
                final label = overdue ? 'OVERDUE' : status.toUpperCase();
                final color = _statusColor(status, overdue: overdue);
                final carName = [
                  data['brand'],
                  data['car_name'] ?? data['carName'],
                ].where((p) => p != null && p.toString().isNotEmpty).join(' ');
                final reason = (data['reason'] ?? 'complimentary').toString();
                final start = _fmt(data['startDate']);
                final end = _fmt(data['endDate']);
                final days = data['days'];
                final price = (data['price_per_day'] as num?)?.toDouble() ?? 0;
                final gifted = _giftedValue(data);

                return Card(
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.card_giftcard,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                carName.isEmpty ? 'Car' : carName,
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
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'For: ${data['recipientName'] ?? 'Guest'}',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        if ((data['phone'] ?? '').toString().isNotEmpty)
                          Text(
                            'Phone: ${data['phone']}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        Text(
                          'Type: ${reason[0].toUpperCase()}${reason.substring(1)}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        if (start.isNotEmpty || end.isNotEmpty)
                          Text(
                            'Period: $start → $end'
                            '${days != null ? ' · $days day(s)' : ''}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        if (gifted > 0)
                          Text(
                            price > 0
                                ? 'Gift value: $days day(s) × ${_egp(price)} = ${_egp(gifted)}'
                                : 'Gift value: ${_egp(gifted)} (not charged)',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if ((data['notes'] ?? '').toString().isNotEmpty)
                          Text(
                            'Note: ${data['notes']}',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        const SizedBox(height: 12),
                        TrafficViolationsAdminPanel(
                          sourceType: TrafficViolationService.sourceGift,
                          rentalId: doc.id,
                          rentalData: data,
                        ),
                        if (status == 'active') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _setStatus(
                                    context,
                                    doc.id,
                                    data,
                                    'cancelled',
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  onPressed: () => _setStatus(
                                    context,
                                    doc.id,
                                    data,
                                    'completed',
                                  ),
                                  child: const Text(
                                    'End rental',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _delete(context, doc.id, data),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
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
}

class AddComplimentaryRentalScreen extends StatefulWidget {
  const AddComplimentaryRentalScreen({super.key});

  @override
  State<AddComplimentaryRentalScreen> createState() =>
      _AddComplimentaryRentalScreenState();
}

class _AddComplimentaryRentalScreenState
    extends State<AddComplimentaryRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final notes = TextEditingController();

  String reason = 'gift';
  String? selectedCarId;
  String selectedCarName = '';
  String selectedBrand = '';
  double pricePerDay = 0;
  DateTime? startDate;
  DateTime? endDate;
  bool _isLoading = false;

  static const _reasons = ['gift', 'complimentary', 'courtesy', 'vip'];

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    notes.dispose();
    super.dispose();
  }

  int get _days {
    if (startDate == null || endDate == null) return 0;
    return RentalDates.rentalDays(startDate!, endDate!);
  }

  double get _total => pricePerDay * _days;

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (startDate ?? DateTime.now())
        : (endDate ?? startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2035),
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        startDate = picked;
        if (endDate != null && endDate!.isBefore(picked)) {
          endDate = picked.add(const Duration(days: 1));
        }
      } else {
        endDate = picked;
      }
    });
  }

  void _applyDuration(int days) {
    final start = startDate ?? DateTime.now();
    setState(() {
      startDate = DateTime(start.year, start.month, start.day);
      // Pickup day counts, so "1 day" ends on the start date.
      endDate = RentalDates.returnDateFor(startDate!, days);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedCarId == null || selectedCarName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a car'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and return dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return date must be after the start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      final admin = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('complimentary_rentals').add({
        'recipientName': name.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'notes': notes.text.trim(),
        'reason': reason,
        'car_id': selectedCarId,
        'car_name': selectedCarName,
        'carName': selectedCarName,
        'brand': selectedBrand,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'pickupDate': Timestamp.fromDate(startDate!),
        'returnDate': Timestamp.fromDate(endDate!),
        'days': _days,
        'price_per_day': pricePerDay,
        'total_amount': _total,
        'gifted_value': _total,
        'status': 'active',
        'amount': 0,
        'charged': false,
        'payment_method': 'complimentary',
        'createdBy': admin?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('cars')
          .doc(selectedCarId)
          .update({'available': false});

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Car granted. It is hidden from the public fleet until returned.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Grant complimentary car'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            const Text(
              'Use this when the owner lends a car as a gift or courtesy — no payment is recorded.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            DarkTextFormField(name, 'Recipient name'),
            DarkTextFormField(
              phone,
              'Phone',
              type: TextInputType.phone,
              required: false,
            ),
            DarkTextFormField(
              email,
              'Email',
              type: TextInputType.emailAddress,
              required: false,
            ),
            DropdownButtonFormField<String>(
              initialValue: reason,
              dropdownColor: Colors.grey.shade900,
              style: const TextStyle(color: Colors.white),
              decoration: darkInputDecoration('Reason'),
              items: _reasons
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(r[0].toUpperCase() + r.substring(1)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => reason = v);
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cars').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final cars = snapshot.data?.docs ?? [];
                if (cars.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No cars in the fleet. Add a car first.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  initialValue: selectedCarId,
                  dropdownColor: Colors.grey.shade900,
                  style: const TextStyle(color: Colors.white),
                  decoration: darkInputDecoration('Car'),
                  hint: const Text(
                    'Select car',
                    style: TextStyle(color: Colors.white70),
                  ),
                  items: cars.map((doc) {
                    final car = doc.data() as Map<String, dynamic>;
                    final carName = (car['name'] ?? 'Car').toString();
                    final brand = (car['brand'] ?? '').toString();
                    final available = car['available'] != false;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        '$brand $carName · EGP ${((car['price_per_day'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/day${available ? '' : ' (currently out)'}'
                            .trim(),
                      ),
                    );
                  }).toList(),
                  validator: (v) => v == null ? 'Required' : null,
                  onChanged: (id) {
                    if (id == null) return;
                    final doc = cars.firstWhere((c) => c.id == id);
                    final car = doc.data() as Map<String, dynamic>;
                    setState(() {
                      selectedCarId = id;
                      selectedCarName = (car['name'] ?? 'Car').toString();
                      selectedBrand = (car['brand'] ?? '').toString();
                      pricePerDay =
                          (car['price_per_day'] as num?)?.toDouble() ?? 0;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('How long?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _chip('1 day', 1),
                _chip('3 days', 3),
                _chip('1 week', 7),
                _chip('2 weeks', 14),
                _chip('1 month', 30),
              ],
            ),
            const SizedBox(height: 12),
            _dateButton(
              'Select start date',
              startDate,
              () => _pickDate(isStart: true),
            ),
            _dateButton(
              'Select return date',
              endDate,
              () => _pickDate(isStart: false),
            ),
            if (_days > 0 && pricePerDay > 0)
              Text(
                '$_days day(s) × EGP ${pricePerDay.toStringAsFixed(0)} = EGP ${_total.toStringAsFixed(0)} (gifted, not charged)',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (_days > 0)
              Text(
                '$_days day(s) · gift value will use the car daily rate',
                style: const TextStyle(color: Colors.orange),
              ),
            const SizedBox(height: 12),
            DarkTextFormField(notes, 'Internal note', required: false),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Grant car',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int days) {
    return ActionChip(
      label: Text(label),
      backgroundColor: Colors.grey.shade900,
      labelStyle: const TextStyle(color: Colors.white),
      side: const BorderSide(color: Colors.orange),
      onPressed: () => _applyDuration(days),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade700),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Text(date == null ? label : DateFormat('dd MMM yyyy').format(date)),
          ],
        ),
      ),
    );
  }
}

class _GiftPersonTotal {
  _GiftPersonTotal({
    required this.key,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String key;
  final String name;
  final String phone;
  final String email;
  int monthCount = 0;
  int yearCount = 0;
  int allCount = 0;
  double monthTotal = 0;
  double yearTotal = 0;
  double allTotal = 0;
}

class _GiftTotalsHeader extends StatelessWidget {
  final double monthTotal;
  final double yearTotal;
  final double allTotal;
  final double filteredTotal;
  final int grantCount;
  final List<_GiftPersonTotal> people;
  final String? selectedPersonKey;
  final String period;
  final bool emptyFilter;
  final String Function(num) format;
  final ValueChanged<String?> onPersonChanged;
  final ValueChanged<String> onPeriodChanged;

  const _GiftTotalsHeader({
    required this.monthTotal,
    required this.yearTotal,
    required this.allTotal,
    required this.filteredTotal,
    required this.grantCount,
    required this.people,
    required this.selectedPersonKey,
    required this.period,
    required this.emptyFilter,
    required this.format,
    required this.onPersonChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = people
        .where((p) => p.key == selectedPersonKey)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey(selectedPersonKey ?? 'all'),
            initialValue: selectedPersonKey,
            dropdownColor: Colors.grey.shade900,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Filter by person',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.person_search, color: Colors.orange),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All people'),
              ),
              ...people.map(
                (person) => DropdownMenuItem<String?>(
                  value: person.key,
                  child: Text(
                    [
                      person.name,
                      if (person.phone.isNotEmpty) person.phone,
                    ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onPersonChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _periodChip('This month', 'month'),
              _periodChip('This year', 'year'),
              _periodChip('All time', 'all'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected == null
                      ? 'Gifted value · ${period == 'month'
                            ? 'this month'
                            : period == 'year'
                            ? 'this year'
                            : 'all time'}'
                      : '${selected.name} · ${period == 'month'
                            ? 'this month'
                            : period == 'year'
                            ? 'this year'
                            : 'all time'}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  format(filteredTotal),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$grantCount grant(s)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _totalTile('This month', format(monthTotal))),
              const SizedBox(width: 10),
              Expanded(child: _totalTile('This year', format(yearTotal))),
              const SizedBox(width: 10),
              Expanded(child: _totalTile('All time', format(allTotal))),
            ],
          ),
          if (people.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Gifted by person',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...people.map((person) {
              final selectedCard = person.key == selectedPersonKey;
              return Card(
                color: selectedCard
                    ? const Color(0xFF3A2A12)
                    : Colors.grey.shade900,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selectedCard ? Colors.orange : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  onTap: () =>
                      onPersonChanged(selectedCard ? null : person.key),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text(
                      person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    person.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    [
                      if (person.phone.isNotEmpty) person.phone,
                      'Month ${format(person.monthTotal)}',
                      'Year ${format(person.yearTotal)}',
                      'All ${format(person.allTotal)}',
                    ].join(' · '),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  trailing: Icon(
                    selectedCard ? Icons.filter_alt : Icons.chevron_right,
                    color: selectedCard ? Colors.orange : Colors.white54,
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              selected == null ? 'All grants' : 'Grants for ${selected.name}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (emptyFilter)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No grants match this person and period.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final selected = period == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: Colors.orange,
      backgroundColor: Colors.grey.shade900,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: selected ? Colors.orange : Colors.grey.shade700),
      onSelected: (_) => onPeriodChanged(value),
    );
  }

  Widget _totalTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

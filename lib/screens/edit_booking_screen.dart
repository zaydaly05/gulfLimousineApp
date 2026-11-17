import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/geo_location.dart';
import '../widgets/extra_km_admin_panel.dart';
import '../widgets/traffic_violations_admin_panel.dart';
import '../services/traffic_violation_service.dart';
import 'map_location_picker.dart';
import 'update_trip_location_screen.dart';
import '../services/booking_service.dart';
import '../utils/rental_dates.dart';
import '../utils/booking_fields.dart';
import '../widgets/condition_video_chips.dart';
import '../widgets/dark_form_fields.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class EditBookingScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const EditBookingScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<EditBookingScreen> createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<EditBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Created once, not in build(): rebuilding it on every setState would
  // reopen the Firestore listener and flash the loading spinner.
  final _carsStream = FirebaseFirestore.instance.collection('cars').snapshots();
  final _chauffeursStream = FirebaseFirestore.instance
      .collection('chauffeurs')
      .where('active', isEqualTo: true)
      .snapshots();

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController phoneController;

  String? selectedCarId;
  String selectedCarName = '';
  String selectedBrand = '';
  double pricePerDay = 0;
  String status = 'pending';
  String tripStatus = 'pending';
  String? chauffeurId;
  String chauffeurName = '';
  String chauffeurPhone = '';
  GeoLocation? pickupLocation;
  GeoLocation? dropoffLocation;

  DateTime? pickupDate;
  DateTime? returnDate;
  bool _isLoading = false;
  late bool _isImmobilized;
  bool _togglingSecurity = false;

  /// True once the admin changes dates or car; until then the booking keeps
  /// the days/total it was created with, so older bookings priced under a
  /// different rule (or with a since-changed car rate) aren't silently
  /// repriced by an unrelated edit such as a status change.
  bool _pricingChanged = false;

  static const _statuses = ['pending', 'confirmed', 'completed', 'cancelled'];

  static const _tripStatuses = [
    'pending',
    'assigned',
    'en_route',
    'arrived',
    'in_progress',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.bookingData;

    nameController = TextEditingController(
      text: (data['customerName'] ?? data['userName'] ?? '').toString(),
    );
    emailController = TextEditingController(
      text: (data['user_email'] ?? '').toString(),
    );
    phoneController = TextEditingController(
      text: (data['phone'] ?? data['phone_number'] ?? '').toString(),
    );

    selectedCarId = data['car_id']?.toString() ?? data['carId']?.toString();
    selectedCarName = (data['carName'] ?? data['car_name'] ?? '').toString();
    selectedBrand = (data['brand'] ?? '').toString();
    pricePerDay = (data['price_per_day'] as num?)?.toDouble() ?? 0;
    status = (data['status'] ?? 'pending').toString().toLowerCase();
    if (!_statuses.contains(status)) status = 'pending';
    tripStatus = (data['tripStatus'] ?? 'pending').toString().toLowerCase();
    if (!_tripStatuses.contains(tripStatus)) tripStatus = 'pending';

    chauffeurId = data['chauffeurId']?.toString();
    chauffeurName = (data['chauffeurName'] ?? '').toString();
    chauffeurPhone = (data['chauffeurPhone'] ?? '').toString();
    pickupLocation = GeoLocation.tryParse(data['pickupLocation']);
    dropoffLocation = GeoLocation.tryParse(data['dropoffLocation']);

    pickupDate = parseFirestoreDate(data['pickupDate'] ?? data['startDate']);
    returnDate = parseFirestoreDate(data['returnDate']);

    final security = data['security'];
    _isImmobilized = security is Map && security['isImmobilized'] == true;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  int get _days {
    final stored = widget.bookingData['days'];
    if (!_pricingChanged && stored is num) return stored.toInt();
    if (pickupDate == null || returnDate == null) return 0;
    return RentalDates.rentalDays(pickupDate!, returnDate!);
  }

  double get _total {
    final stored = widget.bookingData['total_amount'];
    if (!_pricingChanged && stored is num) return stored.toDouble();
    return pricePerDay * _days;
  }

  Future<void> _pickLocation({required bool isPickup}) async {
    final result = await Navigator.push<GeoLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          title: isPickup ? tr('pickupLocation') : tr('dropoffLocation'),
          initial: isPickup ? pickupLocation : dropoffLocation,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (isPickup) {
        pickupLocation = result;
      } else {
        dropoffLocation = result;
      }
    });
  }

  Future<void> _updateBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCarName.isEmpty) {
      ScaffoldMessenger.of(context).showError(tr('pleaseSelectACar'));
      return;
    }
    if (pickupDate == null || returnDate == null) {
      ScaffoldMessenger.of(context).showError(tr('selectPickupReturnDates'));
      return;
    }

    try {
      setState(() => _isLoading = true);

      final previousTrip = (widget.bookingData['tripStatus'] ?? '').toString();
      final previousChauffeur = (widget.bookingData['chauffeurId'] ?? '')
          .toString();

      await BookingService.adminUpdateBooking(widget.bookingId, {
        'customerName': nameController.text.trim(),
        'userName': nameController.text.trim(),
        'user_email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        if (selectedCarId != null) 'car_id': selectedCarId,
        'car_name': selectedCarName,
        'carName': selectedCarName,
        'brand': selectedBrand,
        'pickupDate': Timestamp.fromDate(pickupDate!),
        'returnDate': Timestamp.fromDate(returnDate!),
        'startDate': Timestamp.fromDate(pickupDate!),
        'days': _days,
        'price_per_day': pricePerDay,
        'total_amount': _total,
        'status': status,
        'tripStatus': tripStatus,
        // Delete the id when unassigned, otherwise the customer still sees
        // a chauffeur (and the Track button) after the admin removed them.
        'chauffeurId': chauffeurId ?? FieldValue.delete(),
        'chauffeurName': chauffeurName,
        'chauffeurPhone': chauffeurPhone,
        if (pickupLocation != null) 'pickupLocation': pickupLocation!.toMap(),
        if (dropoffLocation != null)
          'dropoffLocation': dropoffLocation!.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final userId = widget.bookingData['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        if (chauffeurId != null &&
            chauffeurId!.isNotEmpty &&
            chauffeurId != previousChauffeur) {
          await BookingService.notifyChauffeurAssigned(
            userId: userId,
            bookingId: widget.bookingId,
            chauffeurName: chauffeurName,
          );
        } else if (tripStatus != previousTrip) {
          await BookingService.notifyTripStatusChanged(
            userId: userId,
            bookingId: widget.bookingId,
            tripStatus: tripStatus,
          );
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSuccess(tr('bookingUpdatedSuccessfully'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isPickup}) async {
    final initial = isPickup
        ? (pickupDate ?? DateTime.now())
        : (returnDate ?? pickupDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: initial,
    );
    if (picked == null) return;

    setState(() {
      _pricingChanged = true;
      if (isPickup) {
        pickupDate = picked;
        if (returnDate != null && returnDate!.isBefore(picked)) {
          returnDate = picked.add(const Duration(days: 1));
        }
      } else {
        returnDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(tr('editBookingTitle')),
        backgroundColor: Colors.black,
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
            DarkTextFormField(nameController, tr('customerName')),
            DarkTextFormField(
              emailController,
              tr('email'),
              type: TextInputType.emailAddress,
              required: false,
            ),
            DarkTextFormField(
              phoneController,
              tr('phone'),
              type: TextInputType.phone,
              required: false,
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _carsStream,
              builder: (context, snapshot) {
                final cars = snapshot.data?.docs ?? [];
                return DropdownButtonFormField<String>(
                  initialValue:
                      selectedCarId != null &&
                          cars.any((c) => c.id == selectedCarId)
                      ? selectedCarId
                      : null,
                  dropdownColor: Colors.grey.shade900,
                  style: const TextStyle(color: Colors.white),
                  decoration: darkInputDecoration(tr('carFallback')),
                  hint: Text(
                    selectedCarName.isNotEmpty
                        ? selectedCarName
                        : tr('selectCar'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  items: cars.map((doc) {
                    final car = doc.data() as Map<String, dynamic>;
                    final name = (car['name'] ?? tr('carFallback')).toString();
                    final brand = (car['brand'] ?? '').toString();
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text('$brand $name'.trim()),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final doc = cars.firstWhere((c) => c.id == id);
                    final car = doc.data() as Map<String, dynamic>;
                    setState(() {
                      _pricingChanged = true;
                      selectedCarId = id;
                      selectedCarName = (car['name'] ?? tr('carFallback'))
                          .toString();
                      selectedBrand = (car['brand'] ?? '').toString();
                      pricePerDay =
                          (car['price_per_day'] as num?)?.toDouble() ?? 0;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: status,
              dropdownColor: Colors.grey.shade900,
              style: const TextStyle(color: Colors.white),
              decoration: darkInputDecoration(tr('status')),
              items: _statuses
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s, child: Text(statusLabel(s))),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => status = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: tripStatus,
              dropdownColor: Colors.grey.shade900,
              style: const TextStyle(color: Colors.white),
              decoration: darkInputDecoration(tr('tripStatus')),
              items: _tripStatuses
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s, child: Text(statusLabel(s))),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => tripStatus = v);
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _chauffeursStream,
              builder: (context, snapshot) {
                final chauffeurs = snapshot.data?.docs ?? [];
                return DropdownButtonFormField<String>(
                  initialValue:
                      chauffeurId != null &&
                          chauffeurs.any((c) => c.id == chauffeurId)
                      ? chauffeurId
                      : null,
                  dropdownColor: Colors.grey.shade900,
                  style: const TextStyle(color: Colors.white),
                  decoration: darkInputDecoration(tr('chauffeur')),
                  hint: Text(
                    chauffeurName.isNotEmpty
                        ? chauffeurName
                        : tr('assignChauffeur'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  items: [
                    DropdownMenuItem(value: '', child: Text(tr('none'))),
                    ...chauffeurs.map((doc) {
                      final c = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text('${c['name']} · ${ltr(c['phone'] ?? '')}'),
                      );
                    }),
                  ],
                  onChanged: (id) {
                    if (id == null || id.isEmpty) {
                      setState(() {
                        chauffeurId = null;
                        chauffeurName = '';
                        chauffeurPhone = '';
                        if (tripStatus == 'assigned') tripStatus = 'pending';
                      });
                      return;
                    }
                    final doc = chauffeurs.firstWhere((c) => c.id == id);
                    final c = doc.data() as Map<String, dynamic>;
                    setState(() {
                      chauffeurId = id;
                      chauffeurName = (c['name'] ?? '').toString();
                      chauffeurPhone = (c['phone'] ?? '').toString();
                      if (tripStatus == 'pending') tripStatus = 'assigned';
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _locationButton(
              tr('pickupLocation'),
              pickupLocation?.address,
              () => _pickLocation(isPickup: true),
            ),
            _locationButton(
              tr('dropoffLocation'),
              dropoffLocation?.address,
              () => _pickLocation(isPickup: false),
            ),
            _dateButton(
              tr('pickupDate'),
              pickupDate,
              () => _pickDate(isPickup: true),
            ),
            _dateButton(
              tr('returnDateLabel'),
              returnDate,
              () => _pickDate(isPickup: false),
            ),
            if (_days > 0 && pricePerDay > 0) ...[
              const SizedBox(height: 8),
              Text(
                tr(
                  'daySEgpEgp',
                  args: {
                    '_days': '$_days',
                    'toStringAsFixed': pricePerDay.toStringAsFixed(0),
                    'toStringAsFixed2': _total.toStringAsFixed(0),
                  },
                ),
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.bookingData['pickupVideo'] != null ||
                widget.bookingData['returnVideo'] != null) ...[
              Text(
                tr('conditionVideos'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ConditionVideoChips(
                booking: widget.bookingData,
                carName: selectedCarName,
              ),
              const SizedBox(height: 8),
            ],
            ExtraKmAdminPanel(
              bookingId: widget.bookingId,
              booking: widget.bookingData,
            ),
            const SizedBox(height: 12),
            _paymentInfoSection(),
            const SizedBox(height: 12),
            TrafficViolationsAdminPanel(
              sourceType: TrafficViolationService.sourceBooking,
              rentalId: widget.bookingId,
              rentalData: widget.bookingData,
            ),
            const SizedBox(height: 12),
            _securityPanel(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UpdateTripLocationScreen(
                      bookingId: widget.bookingId,
                      bookingData: {
                        ...widget.bookingData,
                        if (pickupLocation != null)
                          'pickupLocation': pickupLocation!.toMap(),
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.gps_fixed, color: Colors.orange),
              label: Text(
                tr('updateLiveLocation'),
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: _isLoading ? null : _updateBooking,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      tr('updateBooking'),
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleImmobilization(bool value) async {
    setState(() => _togglingSecurity = true);
    try {
      await BookingService.toggleImmobilization(
        bookingId: widget.bookingId,
        immobilized: value,
      );
      if (mounted) setState(() => _isImmobilized = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showError(e);
    } finally {
      if (mounted) setState(() => _togglingSecurity = false);
    }
  }

  Widget _securityPanel() {
    final isImmobilized = _isImmobilized;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImmobilized ? Colors.red.shade900 : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isImmobilized ? Colors.red : Colors.grey.shade700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                tr('securityAntiTheft'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isImmobilized
                          ? tr('vehicleImmobilized')
                          : tr('vehicleActive'),
                      style: TextStyle(
                        color: isImmobilized ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      tr('remoteEngineKillSwitchStatus'),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isImmobilized,
                onChanged: _togglingSecurity ? null : _toggleImmobilization,
                activeThumbColor: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentInfoSection() {
    final data = widget.bookingData;
    final method = (data['payment_method'] ?? 'N/A').toString();
    final ref = (data['payment_reference'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                tr('paymentInformation'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(tr('method'), paymentMethodLabel(method)),
          if (ref.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(tr('referenceTxn'), ref, color: Colors.orange),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color color = Colors.white70}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
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
            Text(
              date == null
                  ? label
                  : '$label: ${DateFormat('dd MMM yyyy').format(date)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationButton(String label, String? address, VoidCallback onTap) {
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
            const Icon(Icons.place, size: 18, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                address == null || address.isEmpty ? label : '$label: $address',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

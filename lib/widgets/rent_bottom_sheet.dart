import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/geo_location.dart';
import '../screens/map_location_picker.dart';
import '../screens/payment_screen.dart';
import '../services/booking_service.dart';
import 'expandable_address_row.dart';
import '../l10n/locale_service.dart';
import '../utils/rental_dates.dart';
import '../theme/app_theme.dart';
import '../services/payments_server_client.dart';

class RentBottomSheet extends StatefulWidget {
  final Map<String, dynamic> car;

  const RentBottomSheet({super.key, required this.car});

  @override
  State<RentBottomSheet> createState() => _RentBottomSheetState();
}

class _RentBottomSheetState extends State<RentBottomSheet> {
  DateTime? pickupDate;
  DateTime? returnDate;
  GeoLocation? pickupLocation;
  GeoLocation? dropoffLocation;

  /// Free cars per colour for the chosen dates (from the server).
  FleetAvailability? _avail;
  bool _checking = false;
  String? _availError;
  int _availRequest = 0;
  int _quantity = 1;

  /// Colours in the customer's order of preference.
  List<String> _priority = [];

  double get _pricePerDay =>
      (widget.car['pricePerDay'] as num?)?.toDouble() ?? 0;

  int get _days {
    if (pickupDate == null || returnDate == null) return 0;
    return RentalDates.rentalDays(pickupDate!, returnDate!);
  }

  double get _total => _pricePerDay * _days * _quantity;

  Future<void> _refreshAvailability() async {
    if (pickupDate == null || returnDate == null) return;
    final request = ++_availRequest; // ignore answers to older date choices
    setState(() {
      _checking = true;
      _availError = null;
    });
    try {
      final avail = await BookingService.availability(
        carId: widget.car['id'] as String,
        pickup: pickupDate!,
        returnDate: returnDate!,
      );
      if (!mounted || request != _availRequest) return;
      final names = [
        for (final c in avail.colors)
          if (c.name.isNotEmpty) c.name,
      ];
      setState(() {
        _avail = avail;
        _quantity = _quantity.clamp(
          1,
          avail.totalAvailable < 1 ? 1 : avail.totalAvailable,
        );
        // Keep the customer's order; new colours go last, most free first.
        final kept = [
          for (final n in _priority)
            if (names.contains(n)) n,
        ];
        final added = [
          for (final n in names)
            if (!kept.contains(n)) n,
        ]..sort((a, b) => _freeOf(avail, b).compareTo(_freeOf(avail, a)));
        _priority = [...kept, ...added];
      });
    } on ServerException catch (e) {
      if (mounted && request == _availRequest) {
        setState(() => _availError = e.message);
      }
    } finally {
      if (mounted && request == _availRequest) {
        setState(() => _checking = false);
      }
    }
  }

  static int _freeOf(FleetAvailability a, String name) =>
      a.colors.firstWhere((c) => c.name == name).available;

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _priority.length) return;
    setState(() {
      final item = _priority.removeAt(index);
      _priority.insert(target, item);
    });
  }

  Future<void> _pickDate(bool isPickup) async {
    final now = DateTime.now();
    final last = DateUtils.dateOnly(now.add(const Duration(days: 365)));
    final initial = isPickup
        ? (pickupDate ?? now)
        : (returnDate ??
              pickupDate?.add(const Duration(days: 1)) ??
              now.add(const Duration(days: 1)));

    // Return can't be before pickup, so start its calendar at the pickup date.
    final first = !isPickup && pickupDate != null ? pickupDate! : now;
    // Keep the initial date inside [first, last]; e.g. a pickup on the last
    // bookable day would otherwise put the return calendar past lastDate.
    var start = initial.isBefore(first) ? first : initial;
    if (start.isAfter(last)) start = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isPickup) {
        pickupDate = picked;
        if (returnDate != null && returnDate!.isBefore(picked)) {
          final next = picked.add(const Duration(days: 1));
          returnDate = next.isAfter(last) ? picked : next;
        }
      } else {
        returnDate = picked;
      }
    });
    await _refreshAvailability();
  }

  Future<void> _pickLocation({required bool isPickup}) async {
    final result = await Navigator.push<GeoLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          title: isPickup
              ? context.t('pickupLocation')
              : context.t('dropoffLocation'),
          initial: isPickup ? pickupLocation : dropoffLocation,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        pickupLocation = result;
      } else {
        dropoffLocation = result;
      }
    });
  }

  void _proceedToPayment() {
    if (pickupDate == null || returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('selectPickupReturnDates'))),
      );
      return;
    }
    if (returnDate!.isBefore(pickupDate!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('returnAfterPickup'))));
      return;
    }
    if (_days < 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('rentalMinDay'))));
      return;
    }
    if (pickupLocation == null || dropoffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('selectPickupDropoffLoc'))),
      );
      return;
    }
    final avail = _avail;
    if (avail == null || _checking) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('checkingAvailability'))),
      );
      return;
    }
    if (avail.totalAvailable < _quantity) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('noCarsFree'))));
      return;
    }

    final rental = RentalDetails(
      carId: widget.car['id'] as String,
      carName: widget.car['name'] as String,
      brand: widget.car['brand'] as String? ?? '',
      pricePerDay: _pricePerDay,
      pickupDate: pickupDate!,
      returnDate: returnDate!,
      days: _days,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      quantity: _quantity,
      colorPreferences: avail.hasColors ? List.of(_priority) : const [],
    );

    // Capture the navigator first: this sheet's context goes away on pop.
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => PaymentScreen(rental: rental)),
    );
  }

  /// How many cars, and colours in order of preference, for the dates.
  Widget _fleetSection(BuildContext context) {
    final avail = _avail;
    if (_checking) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(context.t('checkingAvailability')),
          ],
        ),
      );
    }
    if (_availError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _availError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _refreshAvailability,
              child: Text(context.t('retry')),
            ),
          ],
        ),
      );
    }
    if (avail == null) return const SizedBox.shrink();
    if (avail.totalAvailable == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          context.t('noCarsFree'),
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('numberOfCars'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      context.t(
                        'carsFreeOnDates',
                        args: {'n': '${avail.totalAvailable}'},
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t('oneLess'),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                tooltip: context.t('oneMore'),
                onPressed: _quantity < avail.totalAvailable
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          if (avail.hasColors) ...[
            const SizedBox(height: 12),
            Text(
              context.t('colourPreference'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              context.t('colourPreferenceHint'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _priority.length; i++)
              _colourRow(context, avail, i),
          ],
        ],
      ),
    );
  }

  Widget _colourRow(BuildContext context, FleetAvailability avail, int i) {
    final name = _priority[i];
    final free = _freeOf(avail, name);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsetsDirectional.only(start: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.accent,
            child: Text(
              '${i + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: free == 0 ? Colors.grey : null,
              ),
            ),
          ),
          Text(
            free == 0
                ? context.t('noneFree')
                : context.t('freeCount', args: {'n': '$free'}),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          IconButton(
            tooltip: context.t('moveUp'),
            onPressed: i > 0 ? () => _move(i, -1) : null,
            icon: const Icon(Icons.arrow_upward, size: 20),
          ),
          IconButton(
            tooltip: context.t('moveDown'),
            onPressed: i < _priority.length - 1 ? () => _move(i, 1) : null,
            icon: const Icon(Icons.arrow_downward, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.car['name']?.toString() ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.car['brand'] ?? ''} · EGP ${_pricePerDay.toStringAsFixed(0)} ${context.t('perDay')}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            _DateRow(
              label: context.t('pickupDate'),
              value: pickupDate != null
                  ? dateFmt.format(pickupDate!)
                  : context.t('selectDate'),
              onTap: () => _pickDate(true),
            ),
            const SizedBox(height: 12),
            _DateRow(
              label: context.t('returnDateLabel'),
              value: returnDate != null
                  ? dateFmt.format(returnDate!)
                  : context.t('selectDate'),
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 12),
            _LocationRow(
              icon: Icons.place,
              label: context.t('pickupLocation'),
              address: pickupLocation?.address ?? context.t('selectOnMap'),
              onTap: () => _pickLocation(isPickup: true),
            ),
            const SizedBox(height: 12),
            _LocationRow(
              icon: Icons.flag,
              label: context.t('dropoffLocation'),
              address: dropoffLocation?.address ?? context.t('selectOnMap'),
              iconColor: Colors.blue,
              onTap: () => _pickLocation(isPickup: false),
            ),
            if (_days > 0) _fleetSection(context),
            if (_days > 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$_days ${context.t('days')}'
                        '${_quantity > 1 ? ' × $_quantity ${context.t('carsCount')}' : ''}'
                        ' × EGP ${_pricePerDay.toStringAsFixed(0)}',
                      ),
                    ),
                    Text(
                      'EGP ${_total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToPayment,
                child: Text(context.t('continueToPayment')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppTheme.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String label;
  final String address;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;

  const _LocationRow({
    required this.label,
    required this.address,
    required this.onTap,
    this.icon = Icons.place,
    this.iconColor = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  ExpandableAddressText(text: address),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

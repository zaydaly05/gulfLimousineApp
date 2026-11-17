import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_location.dart';
import '../widgets/app_map.dart';
import '../theme/app_theme.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class MapLocationPicker extends StatefulWidget {
  final String title;
  final GeoLocation? initial;

  const MapLocationPicker({super.key, required this.title, this.initial});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late LatLng _pin;
  String _address = '';
  bool _resolving = false;
  final Geocoding? _geocoding = _createGeocoding();
  final _searchController = TextEditingController();
  final _mapController = MapController();

  static final _presets = <String, LatLng>{
    // Keys are translation keys.
    'placeCairoDowntown': kCairoLatLng,
    'placeCairoAirport': const LatLng(30.1219, 31.4056),
    'placeGizaPyramids': const LatLng(29.9792, 31.1342),
    'placeNewCairo': const LatLng(30.0300, 31.4700),
    'placeZamalek': const LatLng(30.0611, 31.2197),
  };

  /// The geocoding plugin has no web implementation, and its constructor
  /// throws where the plugin isn't registered, which used to blank the
  /// whole picker on the web demo. Without it the map still works:
  /// addresses fall back to coordinates and search says it's unavailable.
  static Geocoding? _createGeocoding() {
    try {
      return Geocoding();
    } catch (e) {
      debugPrint('Geocoding unavailable on this platform: $e');
      return null;
    }
  }

  static String _coordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.isValid) {
      _pin = LatLng(initial.lat, initial.lng);
      _address = initial.address;
    } else {
      _pin = kCairoLatLng;
      _address = GeoLocation.cairo.address;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _pin = point;
      _resolving = true;
    });
    final geocoding = _geocoding;
    if (geocoding == null) {
      _address = _coordinates(point);
      if (mounted) setState(() => _resolving = false);
      return;
    }
    try {
      final places = await geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = <String>[
          if (p.street != null && p.street!.trim().isNotEmpty) p.street!.trim(),
          if (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
            p.subLocality!.trim(),
          if (p.locality != null && p.locality!.trim().isNotEmpty)
            p.locality!.trim(),
          if (p.administrativeArea != null &&
              p.administrativeArea!.trim().isNotEmpty)
            p.administrativeArea!.trim(),
        ];
        _address = parts.isEmpty ? _coordinates(point) : parts.join(', ');
      } else {
        _address = _coordinates(point);
      }
    } catch (_) {
      _address = _coordinates(point);
    }
    if (mounted) setState(() => _resolving = false);
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final geocoding = _geocoding;
    if (geocoding == null) {
      ScaffoldMessenger.of(context).showInfo(tr('addressSearchIsnTAvailable'));
      return;
    }
    setState(() => _resolving = true);
    try {
      final results = await geocoding.locationFromAddress(
        '$query, Cairo, Egypt',
      );
      if (results.isNotEmpty) {
        final loc = results.first;
        final point = LatLng(loc.latitude, loc.longitude);
        _mapController.move(point, 15);
        await _reverseGeocode(point);
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showInfo(tr('addressNotFoundTryA'));
    }
  }

  Future<void> _useMyLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showInfo(tr('locationPermissionDenied'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final point = LatLng(pos.latitude, pos.longitude);
      _mapController.move(point, 15);
      await _reverseGeocode(point);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showError(e, title: tr('couldNotGetLocation'));
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      GeoLocation(lat: _pin.latitude, lng: _pin.longitude, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: tr('searchAddressInCairo'),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                    ),
                    onSubmitted: (_) => _searchAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: tr('search'),
                  onPressed: _searchAddress,
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(backgroundColor: AppTheme.accent),
                ),
              ],
            ),
          ),
          // Chips are 48 px tall with their tap target; leave room for it.
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: _presets.entries.map((e) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ActionChip(
                    label: Text(tr(e.key)),
                    onPressed: () async {
                      _mapController.move(e.value, 14);
                      await _reverseGeocode(e.value);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pin,
                    initialZoom: 13,
                    interactionOptions: kAppMapInteraction,
                    onTap: (_, point) => _reverseGeocode(point),
                  ),
                  children: [
                    const AppTileLayer(dark: false),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pin,
                          width: 48,
                          height: 48,
                          // The pin's tip, not its middle, marks the spot.
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            color: AppTheme.accent,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                    AppMapControls(dark: false, onMyLocation: _useMyLocation),
                    const AppMapAttribution(),
                  ],
                ),
                if (_resolving)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _address.isEmpty
                        ? tr('tapMapToChoose')
                        : addressLabel(_address),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    // Wait for the address lookup so the pin and address match.
                    onPressed: _address.isEmpty || _resolving ? null : _confirm,
                    child: Text(tr('confirmLocation')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

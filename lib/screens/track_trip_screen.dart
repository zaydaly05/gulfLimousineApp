import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_location.dart';
import '../services/maps_launcher.dart';
import '../widgets/app_map.dart';
import '../theme/app_theme.dart';
import '../l10n/locale_service.dart';

class TrackTripScreen extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const TrackTripScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    final pickup = GeoLocation.tryParse(bookingData['pickupLocation']);
    final dropoff = GeoLocation.tryParse(bookingData['dropoffLocation']);
    final chauffeurName = (bookingData['chauffeurName'] ?? tr('chauffeur'))
        .toString();
    final chauffeurPhone = (bookingData['chauffeurPhone'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text(tr('trackTrip2'))),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          final data =
              snapshot.data?.data() as Map<String, dynamic>? ?? bookingData;
          final live = LiveLocation.fromMap(
            data['liveLocation'] is Map
                ? Map<String, dynamic>.from(data['liveLocation'] as Map)
                : null,
          );
          final tripStatus = (data['tripStatus'] ?? 'assigned').toString();

          final LatLng center;
          if (live.isValid) {
            center = LatLng(live.lat, live.lng);
          } else if (pickup != null) {
            center = LatLng(pickup.lat, pickup.lng);
          } else {
            center = kCairoLatLng;
          }

          // Everything worth framing: pickup, drop-off and the car.
          final points = [
            if (pickup != null) LatLng(pickup.lat, pickup.lng),
            if (dropoff != null) LatLng(dropoff.lat, dropoff.lng),
            if (live.isValid) LatLng(live.lat, live.lng),
          ];

          final markers = <Marker>[
            if (pickup != null)
              Marker(
                point: LatLng(pickup.lat, pickup.lng),
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accent, width: 2),
                  ),
                  child: const Icon(
                    Icons.place,
                    color: AppTheme.accent,
                    size: 24,
                  ),
                ),
              ),
            if (dropoff != null)
              Marker(
                point: LatLng(dropoff.lat, dropoff.lng),
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: const Icon(Icons.flag, color: Colors.blue, size: 24),
                ),
              ),
            if (live.isValid)
              Marker(
                point: LatLng(live.lat, live.lng),
                width: 60,
                height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tr('yourRide'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.directions_car,
                      color: Colors.green,
                      size: 36,
                    ),
                  ],
                ),
              ),
          ];

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13,
                    initialCameraFit: cameraFitFor(points),
                    interactionOptions: kAppMapInteraction,
                  ),
                  children: [
                    const AppTileLayer(),
                    MarkerLayer(markers: markers),
                    AppMapControls(fitPoints: points),
                    const AppMapAttribution(),
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
                        '${tr('status')}: ${statusLabel(tripStatus)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'chauffeur2',
                          args: {'chauffeurName': chauffeurName},
                        ),
                      ),
                      if (!live.isValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            tr('liveLocationWillAppearOnce'),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (chauffeurPhone.isNotEmpty)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    MapsLauncher.callPhone(chauffeurPhone),
                                icon: const Icon(Icons.call),
                                label: Text(tr('call')),
                              ),
                            ),
                          if (chauffeurPhone.isNotEmpty && pickup != null)
                            const SizedBox(width: 8),
                          if (pickup != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => MapsLauncher.openDirections(
                                  destination: pickup,
                                ),
                                icon: const Icon(Icons.directions),
                                label: Text(tr('pickup')),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

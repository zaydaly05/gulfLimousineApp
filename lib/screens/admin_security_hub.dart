import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/booking_service.dart';
import '../services/whatsapp_service.dart';
import '../utils/safe_insets.dart';
import 'edit_booking_screen.dart';
import '../models/geo_location.dart';
import '../widgets/app_map.dart';
import '../l10n/locale_service.dart';
import '../widgets/app_feedback.dart';

class AdminSecurityHub extends StatefulWidget {
  const AdminSecurityHub({super.key});

  @override
  State<AdminSecurityHub> createState() => _AdminSecurityHubState();
}

class _AdminSecurityHubState extends State<AdminSecurityHub> {
  final MapController _mapController = MapController();
  final _activeTripsStream = FirebaseFirestore.instance
      .collection('bookings')
      .where('tripStatus', isEqualTo: 'in_progress')
      .snapshots();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Firestore may hold coordinates as int or double; LatLng needs doubles.
  static LatLng? _toLatLng(dynamic location) {
    if (location is! Map) return null;
    final lat = location['lat'];
    final lng = location['lng'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('securityAntiTheftHub')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _activeTripsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error);
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final markers = <Marker>[];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final pos = _toLatLng(data['liveLocation']);
            final security = data['security'];
            final carName =
                (data['carName'] ?? data['car_name'] ?? tr('carFallback'))
                    .toString();

            if (pos != null) {
              final isImmobilized =
                  security is Map && security['isImmobilized'] == true;

              markers.add(
                Marker(
                  point: pos,
                  width: 80,
                  height: 80,
                  child: Semantics(
                    button: true,
                    label: carName,
                    child: GestureDetector(
                      onTap: () => _showBookingDetails(doc.id, data),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              carName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.directions_car,
                            color: isImmobilized ? Colors.red : Colors.green,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: kCairoLatLng,
                  initialZoom: 10,
                  interactionOptions: kAppMapInteraction,
                ),
                children: [
                  const AppTileLayer(),
                  // The safe zone sits under the cars, not over them.
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: kCairoLatLng,
                        radius: GeoLocation.geofenceRadiusKm * 1000,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(markers: markers),
                  AppMapControls(fitPoints: [for (final m in markers) m.point]),
                  const AppMapAttribution(),
                ],
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    tr(
                      'monitoringActiveTripsSafeZone',
                      args: {'length': '${docs.length}'},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBookingDetails(String id, Map<String, dynamic> data) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final customerName =
        (data['customerName'] ?? data['userName'] ?? tr('customer')).toString();
    unawaited(
      showModalBottomSheet(
        context: context,
        builder: (sheetContext) {
          final security = data['security'];
          final isImmobilized =
              security is Map && security['isImmobilized'] == true;

          return Container(
            padding: const EdgeInsets.all(20).withSafeBottom(sheetContext),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (data['carName'] ?? data['car_name'] ?? tr('carFallback'))
                      .toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(tr('customer2', args: {'customerName': customerName})),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if ((data['phone'] ?? '').toString().isNotEmpty)
                      IconButton(
                        tooltip: tr('whatsappCustomer'),
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF25D366),
                        ),
                        onPressed: () => WhatsAppService.messageCustomer(
                          phone: data['phone'].toString(),
                          customerName: customerName,
                          bookingId: id,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () {
                        navigator.pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => EditBookingScreen(
                              bookingId: id,
                              bookingData: data,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: Text(tr('manage')),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isImmobilized
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        try {
                          await BookingService.toggleImmobilization(
                            bookingId: id,
                            immobilized: !isImmobilized,
                          );
                        } catch (e) {
                          messenger.showError(e);
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: Icon(isImmobilized ? Icons.lock_open : Icons.lock),
                      label: Text(
                        isImmobilized
                            ? tr('restoreEngine')
                            : tr('engineKillSwitch'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

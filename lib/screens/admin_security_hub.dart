import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/booking_service.dart';
import '../services/whatsapp_service.dart';
import 'edit_booking_screen.dart';

class AdminSecurityHub extends StatefulWidget {
  const AdminSecurityHub({super.key});

  @override
  State<AdminSecurityHub> createState() => _AdminSecurityHubState();
}

class _AdminSecurityHubState extends State<AdminSecurityHub> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Anti-Theft Hub'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('tripStatus', isEqualTo: 'in_progress')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final markers = <Marker>[];
          final alerts = <Map<String, dynamic>>[];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['liveLocation'];
            final security = data['security'];
            final carName = data['carName'] ?? data['car_name'] ?? 'Car';

            if (location != null && location['lat'] != null && location['lng'] != null) {
              final pos = LatLng(location['lat'], location['lng']);
              final isImmobilized = security != null && security['isImmobilized'] == true;

              markers.add(
                Marker(
                  point: pos,
                  width: 80,
                  height: 80,
                  child: GestureDetector(
                    onTap: () => _showBookingDetails(doc.id, data),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            carName,
                            style: const TextStyle(color: Colors.white, fontSize: 10),
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
              );
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(30.0444, 31.2357), // Cairo
                  initialZoom: 10,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.gulflimousine_travel',
                    tileBuilder: (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.6, 0, 0, 0, -60,
                          0, 0.6, 0, 0, -60,
                          0, 0, 0.6, 0, -60,
                          0, 0, 0, 1, 0,
                        ]),
                        child: tileWidget,
                      );
                    },
                  ),
                  MarkerLayer(markers: markers),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: const LatLng(30.0444, 31.2357),
                        radius: 100000, // 100km
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Monitoring ${docs.length} Active Trips\nSafe Zone: 100km radius from Cairo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final security = data['security'];
        final isImmobilized = security != null && security['isImmobilized'] == true;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['carName'] ?? data['car_name'] ?? 'Car',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text('Customer: ${data['customerName'] ?? data['userName']}'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if ((data['phone'] ?? '').toString().isNotEmpty)
                    IconButton(
                      tooltip: 'WhatsApp Customer',
                      icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                      onPressed: () => WhatsAppService.messageCustomer(
                        phone: data['phone'].toString(),
                        customerName: data['customerName'] ?? data['userName'] ?? 'Customer',
                        bookingId: id,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditBookingScreen(bookingId: id, bookingData: data),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Manage'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isImmobilized ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await BookingService.toggleImmobilization(
                        bookingId: id,
                        immobilized: !isImmobilized,
                      );
                      if (mounted) Navigator.pop(context);
                    },
                    icon: Icon(isImmobilized ? Icons.lock_open : Icons.lock),
                    label: Text(isImmobilized ? 'Restore Engine' : 'Engine Kill Switch'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
